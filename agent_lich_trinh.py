import os
import re
from dotenv import load_dotenv
from datetime import date, timedelta, datetime
from typing import Optional

from fastapi import FastAPI
from pydantic import BaseModel
from sqlalchemy import create_engine, text
from sqlalchemy.engine.base import Engine

from langchain.agents import AgentExecutor, create_tool_calling_agent
from langchain.tools import tool
from langchain_core.chat_history import BaseChatMessageHistory
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_core.runnables.history import RunnableWithMessageHistory
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_community.chat_message_histories import ChatMessageHistory

# --- 1. CẤU HÌNH & KẾT NỐI ---

load_dotenv()
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    raise ValueError("❌ Không tìm thấy DATABASE_URL trong .env")

engine: Engine = create_engine(
    DATABASE_URL, pool_pre_ping=True, pool_recycle=300)

llm_brain = ChatGoogleGenerativeAI(
    model="gemini-2.5-flash", google_api_key=GEMINI_API_KEY, temperature=0)

CURRENT_USER_ID = 1

# --- 2. HÀM TIỆN ÍCH VỀ THỜI GIAN (TÍCH HỢP TỪ UTILS) ---
# (Phần này được tích hợp để file có thể chạy độc lập)


def parse_natural_time(expression: str, base_date: datetime) -> tuple[datetime, datetime]:
    expr = expression.lower().strip()
    new_start = base_date

    match = re.search(r"(\d+)\s*(ngày|tuần|tháng|năm)\s*(sau|tới|trước)", expr)
    if match:
        amount, unit, direction = int(
            match.group(1)), match.group(2), match.group(3)
        multiplier = 1 if direction in ["sau", "tới"] else -1
        if unit == "ngày":
            new_start += timedelta(days=amount * multiplier)
        elif unit == "tuần":
            new_start += timedelta(weeks=amount * multiplier)
        elif unit == "tháng":
            new_start = add_months(new_start, amount * multiplier)
        elif unit == "năm":
            new_start = add_years(new_start, amount * multiplier)
    elif "tuần sau" in expr:
        new_start += timedelta(weeks=1)
    elif "tuần trước" in expr:
        new_start -= timedelta(weeks=1)
    elif "tháng sau" in expr:
        new_start = add_months(new_start, 1)
    # ... (các logic khác của parse_natural_time có thể thêm vào đây)

    return new_start, new_start + timedelta(hours=1)


def add_months(dt: datetime, months: int) -> datetime:
    month = dt.month - 1 + months
    year = dt.year + month // 12
    month = month % 12 + 1
    day = min(dt.day, 28)
    return dt.replace(year=year, month=month, day=day)


def add_years(dt: datetime, years: int) -> datetime:
    try:
        return dt.replace(year=dt.year + years)
    except ValueError:
        return dt.replace(month=2, day=28, year=dt.year + years)

# --- 3. CÔNG CỤ (TOOLS) ---


@tool
def tao_task_va_len_lich(tieu_de: str, thoi_gian_bat_dau: str, thoi_gian_ket_thuc: str) -> str:
    """Tạo và lên lịch một sự kiện mới."""
    try:
        with engine.connect() as connection:
            with connection.begin() as transaction:
                task_query = text(
                    "INSERT INTO tasks (user_id, title) VALUES (:user_id, :title) RETURNING id;")
                result = connection.execute(
                    task_query, {"user_id": CURRENT_USER_ID, "title": tieu_de})
                task_id = result.scalar_one_or_none()
                if not task_id:
                    raise Exception("Không thể tạo task mới.")
                schedule_query = text(
                    "INSERT INTO schedules (user_id, task_id, start_time, end_time) VALUES (:user_id, :task_id, :start_time, :end_time);")
                connection.execute(schedule_query, {
                                   "user_id": CURRENT_USER_ID, "task_id": task_id, "start_time": thoi_gian_bat_dau, "end_time": thoi_gian_ket_thuc})
                transaction.commit()
                return f"✅ Đã lên lịch '{tieu_de}' lúc {thoi_gian_bat_dau}."
    except Exception as e:
        return f"❌ Lỗi khi tạo task: {e}"


@tool
def xoa_task_theo_lich(tieu_de: str) -> str:
    """Xóa một sự kiện đã có theo tiêu đề."""
    try:
        with engine.connect() as connection:
            with connection.begin() as transaction:
                query = text(
                    "DELETE FROM tasks WHERE title = :title AND user_id = :user_id;")
                result = connection.execute(
                    query, {"title": tieu_de, "user_id": CURRENT_USER_ID})
                transaction.commit()
                if result.rowcount > 0:
                    return f"🗑️ Đã xóa '{tieu_de}'."
                else:
                    return f"⚠️ Không tìm thấy '{tieu_de}' để xóa."
    except Exception as e:
        return f"❌ Lỗi khi xóa: {e}"


@tool
def tim_lich_trinh(ngay_bat_dau: str, ngay_ket_thuc: str) -> str:
    """Tìm các sự kiện trong một khoảng ngày được chỉ định."""
    try:
        with engine.connect() as connection:
            query = text("SELECT t.title, s.start_time FROM schedules s JOIN tasks t ON s.task_id = t.id WHERE s.user_id = :user_id AND s.start_time::date BETWEEN :start_date AND :end_date ORDER BY s.start_time LIMIT 10;")
            results = connection.execute(query, {
                                         "user_id": CURRENT_USER_ID, "start_date": ngay_bat_dau, "end_date": ngay_ket_thuc}).fetchall()
            if not results:
                return f"📭 Không có sự kiện nào từ {ngay_bat_dau} đến {ngay_ket_thuc}."
            events = [
                f"- '{row.title}' lúc {row.start_time.strftime('%H:%M ngày %d/%m/%Y')}" for row in results]
            return f"🔎 Bạn có {len(events)} sự kiện:\n" + "\n".join(events)
    except Exception as e:
        return f"❌ Lỗi khi tìm lịch: {e}"

# === SỬA LẠI HOÀN TOÀN HÀM CHINH_SUA_TASK ===


@tool
def chinh_sua_task(tieu_de_cu: str, thoi_gian_moi: str) -> str:
    """Chỉnh sửa thời gian của một sự kiện đã có. Tham số `thoi_gian_moi` có thể là ngày giờ cụ thể hoặc một cụm từ tương đối (vd: '2 tuần sau')."""
    try:
        with engine.connect() as connection:
            with connection.begin() as transaction:
                find_query = text(
                    "SELECT t.id, s.start_time FROM tasks t JOIN schedules s ON t.id = s.task_id WHERE t.title = :title AND t.user_id = :user_id;")
                original_task = connection.execute(
                    find_query, {"title": tieu_de_cu, "user_id": CURRENT_USER_ID}).fetchone()
                if not original_task:
                    return f"⚠️ Không tìm thấy '{tieu_de_cu}' để chỉnh sửa."

                task_id, old_start_time = original_task.id, original_task.start_time

                # Gọi hàm parse_natural_time để tính toán thời gian mới một cách thông minh
                new_start, new_end = parse_natural_time(
                    thoi_gian_moi, base_date=old_start_time)

                update_query = text(
                    "UPDATE schedules SET start_time = :start_time, end_time = :end_time WHERE task_id = :task_id;")
                result = connection.execute(
                    update_query, {"start_time": new_start, "end_time": new_end, "task_id": task_id})
                transaction.commit()

                if result.rowcount > 0:
                    return f"✅ Đã dời '{tieu_de_cu}' sang {new_start.strftime('%H:%M %d/%m/%Y')}."
                else:
                    return f"⚠️ Không thể cập nhật '{tieu_de_cu}'."
    except Exception as e:
        return f"❌ Lỗi khi chỉnh sửa: {e}"

# --- 4. LẮP RÁP AGENT & BỘ NHỚ ---


tools_list = [tao_task_va_len_lich,
              xoa_task_theo_lich, tim_lich_trinh, chinh_sua_task]

today = date.today()
start_of_this_week = today - timedelta(days=today.weekday())
end_of_this_week = start_of_this_week + timedelta(days=6)
start_of_next_week = start_of_this_week + timedelta(days=7)
end_of_next_week = start_of_next_week + timedelta(days=6)

system_prompt_template = f"""
Bạn là Agent tự hành, không phải chatbot. Chỉ gọi tools. KHÔNG BAO GIỜ hỏi lại.
BỐI CẢNH: Hôm nay là {today.strftime('%A, %d/%m/%Y')}.
QUY TẮC:
1. Tự tính toán ngày và truyền vào tool:
   - 'hôm nay' -> `{today.isoformat()}`.
   - 'tuần này' -> từ `{start_of_this_week.isoformat()}` đến `{end_of_this_week.isoformat()}`.
   - 'tuần sau' -> từ `{start_of_next_week.isoformat()}` đến `{end_of_next_week.isoformat()}`.
2. Với yêu cầu CHỈNH SỬA, hãy trích xuất TOÀN BỘ cụm thời gian mới (vd: '2 tuần sau', 'đầu tháng tới', '15h ngày mai') và truyền nó vào tham số `thoi_gian_moi` của công cụ `chinh_sua_task`.
3. Nếu không có giờ cụ thể cho việc TẠO MỚI -> mặc định 09:00 - 10:00. Nếu có giờ bắt đầu, không có giờ kết thúc -> mặc định kéo dài 1 tiếng.
"""

prompt = ChatPromptTemplate.from_messages([
    ("system", system_prompt_template), MessagesPlaceholder(
        variable_name="chat_history"),
    ("human", "{input}"), MessagesPlaceholder(
        variable_name="agent_scratchpad"),
])

agent = create_tool_calling_agent(llm_brain, tools_list, prompt)
agent_executor = AgentExecutor(agent=agent, tools=tools_list, verbose=True)

store = {}


def get_session_history(session_id: str) -> BaseChatMessageHistory:
    if session_id not in store:
        store[session_id] = ChatMessageHistory()
    return store[session_id]


agent_with_chat_history = RunnableWithMessageHistory(
    agent_executor, get_session_history,
    input_messages_key="input", history_messages_key="chat_history",
)

# --- 5. API SERVER ---

app = FastAPI(title="Skedule AI Agent API", version="1.3.0")


class UserRequest(BaseModel):
    prompt: str


@app.get("/")
def read_root():
    return {"message": "Skedule AI Agent is running!"}


@app.post("/chat")
async def handle_chat_request(request: UserRequest):
    user_prompt = request.prompt
    session_id = "default_user_session"
    print(f"📨 Prompt nhận: {user_prompt}")

    final_result = agent_with_chat_history.invoke(
        {"input": user_prompt},
        config={"configurable": {"session_id": session_id}}
    )
    ai_response = final_result.get(
        "output", "Lỗi: Không có phản hồi từ agent.")
    return {"response": ai_response}
