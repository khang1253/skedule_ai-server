import os
import re
from dotenv import load_dotenv
from datetime import date, timedelta, datetime
from typing import Optional

from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel
from sqlalchemy import create_engine, text
from sqlalchemy.engine.base import Engine

# === IMPORT MỚI CHO SUPABASE PYTHON ===
from supabase import create_client, Client

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
# === THÊM BIẾN MÔI TRƯỜNG CHO SUPABASE ===
SUPABASE_URL = os.getenv("SUPABASE_URL")
# Sửa tên cho khớp với file .env của Flutter
SUPABASE_KEY = os.getenv("SUPABASE_ANON_KEY")

if not all([DATABASE_URL, SUPABASE_URL, SUPABASE_KEY]):
    raise ValueError(
        "❌ Thiếu các biến môi trường cần thiết (DATABASE_URL, SUPABASE_URL, SUPABASE_ANON_KEY) trong file .env")

# Khởi tạo kết nối CSDL và Supabase client
engine: Engine = create_engine(
    DATABASE_URL, pool_pre_ping=True, pool_recycle=300)
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

llm_brain = ChatGoogleGenerativeAI(
    model="gemini-2.5-flash", google_api_key=GEMINI_API_KEY, temperature=0)

# --- 2. XÁC THỰC NGƯỜI DÙNG (NÂNG CẤP BẢO MẬT) ---

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")


def get_current_user_id(token: str = Depends(oauth2_scheme)) -> str:
    """Xác thực Access Token từ header và trả về user ID (dạng UUID string)."""
    try:
        user_response = supabase.auth.get_user(token)
        user_id = user_response.user.id
        print(f"👤 User ID đã xác thực: {user_id}")
        return str(user_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token không hợp lệ hoặc đã hết hạn.",
        )

# --- 3. HÀM TIỆN ÍCH VỀ THỜI GIAN ---


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
    # ... (có thể thêm các logic khác)
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


# --- 4. CÔNG CỤ (TOOLS) - ĐÃ ĐƯỢC NÂNG CẤP ---

@tool
def tao_task_va_len_lich(tieu_de: str, thoi_gian_bat_dau: str, thoi_gian_ket_thuc: str, user_id: str) -> str:
    """Tạo và lên lịch một sự kiện mới cho một user cụ thể."""
    try:
        with engine.connect() as connection:
            with connection.begin() as transaction:
                task_query = text(
                    "INSERT INTO tasks (user_id, title) VALUES (:user_id, :title) RETURNING id;")
                result = connection.execute(
                    task_query, {"user_id": user_id, "title": tieu_de})
                task_id = result.scalar_one_or_none()
                if not task_id:
                    raise Exception("Không thể tạo task mới.")
                schedule_query = text(
                    "INSERT INTO schedules (user_id, task_id, start_time, end_time) VALUES (:user_id, :task_id, :start_time, :end_time);")
                connection.execute(schedule_query, {
                                   "user_id": user_id, "task_id": task_id, "start_time": thoi_gian_bat_dau, "end_time": thoi_gian_ket_thuc})
                transaction.commit()
                return f"✅ Đã lên lịch '{tieu_de}' lúc {thoi_gian_bat_dau}."
    except Exception as e:
        return f"❌ Lỗi khi tạo task: {e}"


@tool
def xoa_task_theo_lich(tieu_de: str, user_id: str) -> str:
    """Xóa một sự kiện đã có theo tiêu đề cho một user cụ thể."""
    try:
        with engine.connect() as connection:
            with connection.begin() as transaction:
                query = text(
                    "DELETE FROM tasks WHERE title = :title AND user_id = :user_id;")
                result = connection.execute(
                    query, {"title": tieu_de, "user_id": user_id})
                transaction.commit()
                if result.rowcount > 0:
                    return f"🗑️ Đã xóa '{tieu_de}'."
                else:
                    return f"⚠️ Không tìm thấy '{tieu_de}' để xóa."
    except Exception as e:
        return f"❌ Lỗi khi xóa: {e}"


@tool
def tim_lich_trinh(ngay_bat_dau: str, ngay_ket_thuc: str, user_id: str) -> str:
    """Tìm các sự kiện trong một khoảng ngày được chỉ định cho một user cụ thể."""
    try:
        with engine.connect() as connection:
            query = text("SELECT t.title, s.start_time FROM schedules s JOIN tasks t ON s.task_id = t.id WHERE s.user_id = :user_id AND s.start_time::date BETWEEN :start_date AND :end_date ORDER BY s.start_time LIMIT 10;")
            results = connection.execute(query, {
                                         "user_id": user_id, "start_date": ngay_bat_dau, "end_date": ngay_ket_thuc}).fetchall()
            if not results:
                return f"📭 Không có sự kiện nào từ {ngay_bat_dau} đến {ngay_ket_thuc}."
            events = [
                f"- '{row.title}' lúc {row.start_time.strftime('%H:%M ngày %d/%m/%Y')}" for row in results]
            return f"🔎 Bạn có {len(events)} sự kiện:\n" + "\n".join(events)
    except Exception as e:
        return f"❌ Lỗi khi tìm lịch: {e}"


@tool
def chinh_sua_task(tieu_de_cu: str, thoi_gian_moi: str, user_id: str) -> str:
    """Chỉnh sửa thời gian của một sự kiện đã có cho một user cụ thể."""
    try:
        with engine.connect() as connection:
            with connection.begin() as transaction:
                find_query = text(
                    "SELECT t.id, s.start_time FROM tasks t JOIN schedules s ON t.id = s.task_id WHERE t.title = :title AND t.user_id = :user_id;")
                original_task = connection.execute(
                    find_query, {"title": tieu_de_cu, "user_id": user_id}).fetchone()
                if not original_task:
                    return f"⚠️ Không tìm thấy '{tieu_de_cu}' để chỉnh sửa."
                task_id, old_start_time = original_task.id, original_task.start_time
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

# --- 5. LẮP RÁP AGENT & BỘ NHỚ ---


tools_list = [tao_task_va_len_lich,
              xoa_task_theo_lich, tim_lich_trinh, chinh_sua_task]

today = date.today()
# ... (phần tạo prompt động giữ nguyên)

system_prompt_template = f"""
Bạn là Agent tự hành, không phải chatbot. Chỉ gọi tools. KHÔNG BAO GIỜ hỏi lại.
BỐI CẢNH: Hôm nay là {today.strftime('%A, %d/%m/%Y')}.
QUY TẮC:
1. Luôn phải truyền `user_id` được cung cấp vào các công cụ.
2. Tự tính toán ngày và truyền vào tool.
3. Với CHỈNH SỬA, trích xuất toàn bộ cụm thời gian mới và truyền vào `thoi_gian_moi`.
4. Nếu không có giờ cho TẠO MỚI -> mặc định 9h-10h. Nếu có giờ bắt đầu, không có giờ kết thúc -> mặc định 1 tiếng.
"""

prompt = ChatPromptTemplate.from_messages([
    ("system", system_prompt_template),
    MessagesPlaceholder(variable_name="chat_history"),
    ("human", "{input}"),
    MessagesPlaceholder(variable_name="agent_scratchpad"),
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

# --- 6. API SERVER ---

app = FastAPI(title="Skedule AI Agent API", version="1.4.0")


class UserRequest(BaseModel):
    prompt: str


@app.get("/")
def read_root():
    return {"message": "Skedule AI Agent is running!"}


@app.post("/chat")
async def handle_chat_request(request: UserRequest, user_id: str = Depends(get_current_user_id)):
    user_prompt = request.prompt
    session_id = f"user_{user_id}"
    print(f"📨 Prompt nhận từ user {user_id}: {user_prompt}")

    final_result = agent_with_chat_history.invoke(
        # Truyền user_id vào cho agent
        {"input": user_prompt, "user_id": user_id},
        config={"configurable": {"session_id": session_id}}
    )
    ai_response = final_result.get(
        "output", "Lỗi: Không có phản hồi từ agent.")
    return {"response": ai_response}
