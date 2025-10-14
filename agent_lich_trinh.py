# File: agent_lich_trinh.py

import os
import io
import base64
import re 
from dotenv import load_dotenv
from datetime import date, timedelta

from fastapi import FastAPI, Depends, HTTPException, status, File, UploadFile, Form
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel
from sqlalchemy import create_engine, text
from sqlalchemy.engine.base import Engine

from supabase import create_client, Client
from gtts import gTTS
import speech_recognition as sr
from pydub import AudioSegment

from langchain.agents import AgentExecutor, create_tool_calling_agent
from langchain.tools import tool
from langchain_core.chat_history import BaseChatMessageHistory
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_core.runnables.history import RunnableWithMessageHistory
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_community.chat_message_histories import ChatMessageHistory

# Import hàm xử lý thời gian từ module utils
from utils.thoi_gian_tu_nhien import parse_natural_time

# --- 1. CẤU HÌNH & KẾT NỐI ---
load_dotenv()

ffmpeg_path = os.getenv("FFMPEG_PATH")
if ffmpeg_path and os.path.exists(ffmpeg_path):
    AudioSegment.converter = ffmpeg_path
    print(f"✅ Đã tìm thấy và sử dụng FFmpeg tại: {ffmpeg_path}")
else:
    print("⚠️ Cảnh báo: Không tìm thấy FFmpeg. Chức năng xử lý giọng nói có thể không hoạt động.")

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
DATABASE_URL = os.getenv("DATABASE_URL")
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_ANON_KEY")

if not all([DATABASE_URL, SUPABASE_URL, SUPABASE_KEY, GEMINI_API_KEY]):
    raise ValueError("❌ Thiếu các biến môi trường cần thiết trong file .env")

engine: Engine = create_engine(DATABASE_URL, pool_pre_ping=True, pool_recycle=300)
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
llm_brain = ChatGoogleGenerativeAI(model="gemini-2.5-flash", google_api_key=GEMINI_API_KEY, temperature=0.7)

# --- 2. XÁC THỰC NGƯỜI DÙNG ---
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

def get_current_user_id(token: str = Depends(oauth2_scheme)) -> str:
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

# --- 3. CÁC HÀM XỬ LÝ GIỌNG NÓI ---
def clean_text_for_speech(text: str) -> str:
    cleaned_text = text.replace('*', '')
    cleaned_text = cleaned_text.replace('_', '')
    cleaned_text = re.sub(r'^\s*-\s*', '. ', cleaned_text, flags=re.MULTILINE)
    return cleaned_text

def text_to_base64_audio(text: str) -> str:
    try:
        speech_text = clean_text_for_speech(text)
        tts = gTTS(speech_text, lang='vi', slow=False)
        audio_fp = io.BytesIO()
        tts.write_to_fp(audio_fp)
        audio_fp.seek(0)
        audio_bytes = audio_fp.read()
        return base64.b64encode(audio_bytes).decode('utf-8')
    except Exception as e:
        print(f"Lỗi TTS: {e}")
        return ""

async def audio_to_text(audio_file: UploadFile) -> str:
    r = sr.Recognizer()
    try:
        audio_bytes = await audio_file.read()
        audio_fp = io.BytesIO(audio_bytes)
        sound = AudioSegment.from_file(audio_fp)

        if len(sound) < 500:
            raise HTTPException(status_code=400, detail="File âm thanh quá ngắn. Vui lòng nhấn giữ nút micro để nói.")

        wav_fp = io.BytesIO()
        sound.export(wav_fp, format="wav")
        wav_fp.seek(0)

        with sr.AudioFile(wav_fp) as source:
            audio_data = r.record(source)
            try:
                text = r.recognize_google(audio_data, language="vi-VN")
                print(f"🎤 Văn bản nhận dạng được: {text}")
                return text
            except sr.UnknownValueError:
                raise HTTPException(status_code=400, detail="Rất tiếc, tôi không nghe rõ bạn nói. Vui lòng thử nói chậm và rõ ràng hơn.")
            except sr.RequestError as e:
                raise HTTPException(status_code=503, detail=f"Dịch vụ nhận dạng giọng nói tạm thời không khả dụng. Lỗi: {e}")

    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=f"Đã xảy ra lỗi không mong muốn khi xử lý file âm thanh.")

# --- 4. CÁC CÔNG CỤ (TOOLS) CHO AGENT ---
# (Toàn bộ các tool cũ giữ nguyên, không thay đổi)
@tool
def tao_task_va_len_lich(tieu_de: str, thoi_gian_bat_dau: str, thoi_gian_ket_thuc: str, user_id: str) -> str:
    """Tạo và lên lịch một sự kiện mới cho một user cụ thể."""
    try:
        with engine.connect() as connection:
            with connection.begin() as transaction:
                task_query = text("INSERT INTO tasks (user_id, title, is_completed) VALUES (:user_id, :title, FALSE) RETURNING id;")
                result = connection.execute(task_query, {"user_id": user_id, "title": tieu_de})
                task_id = result.scalar_one_or_none()
                if not task_id:
                    raise Exception("Không thể tạo task mới.")
                schedule_query = text("INSERT INTO schedules (user_id, task_id, start_time, end_time) VALUES (:user_id, :task_id, :start_time, :end_time);")
                connection.execute(schedule_query, {"user_id": user_id, "task_id": task_id, "start_time": thoi_gian_bat_dau, "end_time": thoi_gian_ket_thuc})
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
                query = text("DELETE FROM tasks WHERE unaccent(title) ILIKE unaccent(:title) AND user_id = :user_id;")
                result = connection.execute(query, {"title": f"%{tieu_de}%", "user_id": user_id})
                transaction.commit()
                if result.rowcount > 0:
                    return f"🗑️ Đã xóa thành công lịch trình có chứa từ khóa '{tieu_de}'."
                else:
                    return f"⚠️ Không tìm thấy lịch trình nào có tên '{tieu_de}' để xóa."
    except Exception as e:
        return f"❌ Lỗi khi xóa: {e}"

@tool
def tim_lich_trinh(ngay_bat_dau: str, ngay_ket_thuc: str, user_id: str) -> str:
    """Tìm các sự kiện trong một khoảng ngày được chỉ định cho một user cụ thể."""
    try:
        with engine.connect() as connection:
            query = text("SELECT t.title, s.start_time FROM schedules s JOIN tasks t ON s.task_id = t.id WHERE s.user_id = :user_id AND s.start_time::date BETWEEN :start_date AND :end_date ORDER BY s.start_time LIMIT 10;")
            results = connection.execute(query, {"user_id": user_id, "start_date": ngay_bat_dau, "end_date": ngay_ket_thuc}).fetchall()
            if not results:
                return f"📭 Bạn không có sự kiện nào từ {ngay_bat_dau} đến {ngay_ket_thuc}."
            events = [f"- '{row.title}' lúc {row.start_time.strftime('%H:%M ngày %d/%m/%Y')}" for row in results]
            return f"🔎 Bạn có {len(events)} sự kiện:\n" + "\n".join(events)
    except Exception as e:
        return f"❌ Lỗi khi tìm lịch: {e}"

@tool
def chinh_sua_task(tieu_de_cu: str, thoi_gian_moi: str, user_id: str) -> str:
    """Chỉnh sửa thời gian của một sự kiện đã có cho một user cụ thể."""
    try:
        with engine.connect() as connection:
            with connection.begin() as transaction:
                find_query = text("SELECT t.id, s.start_time FROM tasks t JOIN schedules s ON t.id = s.task_id WHERE unaccent(t.title) ILIKE unaccent(:title) AND t.user_id = :user_id;")
                original_task = connection.execute(find_query, {"title": f"%{tieu_de_cu}%", "user_id": user_id}).fetchone()
                if not original_task:
                    return f"⚠️ Không tìm thấy '{tieu_de_cu}' để chỉnh sửa."
                
                task_id, old_start_time = original_task.id, original_task.start_time
                new_start, new_end = parse_natural_time(thoi_gian_moi, base_date=old_start_time)
                
                update_query = text("UPDATE schedules SET start_time = :start_time, end_time = :end_time WHERE task_id = :task_id;")
                result = connection.execute(update_query, {"start_time": new_start, "end_time": new_end, "task_id": task_id})
                transaction.commit()

                if result.rowcount > 0:
                    return f"✅ Đã dời '{tieu_de_cu}' sang {new_start.strftime('%H:%M %d/%m/%Y')}."
                else:
                    return f"⚠️ Không thể cập nhật '{tieu_de_cu}'."
    except Exception as e:
        return f"❌ Lỗi khi chỉnh sửa: {e}"

@tool
def danh_dau_task_hoan_thanh(tieu_de: str, user_id: str) -> str:
    """Đánh dấu một công việc là đã hoàn thành dựa vào tiêu đề của nó."""
    try:
        with engine.connect() as connection:
            with connection.begin() as transaction:
                query = text("UPDATE tasks SET is_completed = TRUE WHERE unaccent(title) ILIKE unaccent(:title) AND user_id = :user_id;")
                result = connection.execute(query, {"title": f"%{tieu_de}%", "user_id": user_id})
                transaction.commit()
                
                if result.rowcount > 0:
                    return f"👍 Rất tốt! Đã đánh dấu '{tieu_de}' là đã hoàn thành."
                else:
                    return f"🤔 Không tìm thấy công việc nào có tên '{tieu_de}' để đánh dấu hoàn thành."
    except Exception as e:
        return f"❌ Lỗi khi đánh dấu hoàn thành: {e}"

@tool
def tom_tat_tien_do(user_id: str) -> str:
    """Cung cấp tóm tắt về lịch trình của người dùng. Dùng khi người dùng hỏi chung chung."""
    try:
        with engine.connect() as connection:
            total_query = text("SELECT COUNT(*) FROM tasks WHERE user_id = :user_id;")
            total_tasks = connection.execute(total_query, {"user_id": user_id}).scalar_one()
            
            completed_query = text("SELECT COUNT(*) FROM tasks WHERE user_id = :user_id AND is_completed = TRUE;")
            completed_tasks = connection.execute(completed_query, {"user_id": user_id}).scalar_one()
            
            upcoming_query = text("SELECT t.title, s.start_time FROM schedules s JOIN tasks t ON s.task_id = t.id WHERE s.user_id = :user_id AND s.start_time > NOW() AND t.is_completed = FALSE ORDER BY s.start_time ASC LIMIT 3;")
            upcoming_results = connection.execute(upcoming_query, {"user_id": user_id}).fetchall()
            
            summary = f"Tổng quan lịch trình của bạn:\n- 📊 Tổng cộng: {total_tasks} công việc.\n- ✅ Hoàn thành: {completed_tasks} công việc.\n"
            if upcoming_results:
                summary += "- 🗓️ Các lịch trình chưa hoàn thành sắp tới:\n" + "\n".join([f"  - '{row.title}' lúc {row.start_time.strftime('%H:%M %d/%m')}" for row in upcoming_results])
            else:
                summary += "- 🗓️ Bạn không có lịch trình nào sắp tới hoặc tất cả đều đã hoàn thành."
            return summary
    except Exception as e:
        if "is_completed" in str(e):
             return "Lỗi: Bảng 'tasks' của bạn cần có cột 'is_completed' kiểu BOOLEAN để sử dụng chức năng này."
        return f"❌ Lỗi khi tóm tắt: {e}"

# --- 5. LẮP RÁP AGENT & BỘ NHỚ ---
tools_list = [tao_task_va_len_lich, xoa_task_theo_lich, tim_lich_trinh, chinh_sua_task, danh_dau_task_hoan_thanh, tom_tat_tien_do]
today = date.today()
system_prompt_template = f"""
Bạn là một trợ lý lịch trình AI hữu ích và thân thiện tên là Skedule.
BỐI CẢNH: Hôm nay là {today.strftime('%A, %d/%m/%Y')}.
QUY TẮC:
1. Luôn sử dụng các công cụ (tools) có sẵn để thực hiện yêu cầu.
2. Luôn sử dụng `user_id` được cung cấp trong prompt để gọi tool.
3. ***RẤT QUAN TRỌNG***: Khi gọi tool `tim_lich_trinh`, BẮT BUỘC phải truyền ngày tháng theo định dạng 'YYYY-MM-DD'.
4. Khi người dùng muốn đánh dấu một công việc là "xong", "hoàn thành", "đã làm", hãy sử dụng tool `danh_dau_task_hoan_thanh`.
5. Sau khi tool chạy xong, hãy diễn giải kết quả đó thành một câu trả lời tự nhiên, đầy đủ và lịch sự.
6. Nếu người dùng hỏi chung chung như "tôi có lịch trình gì không?", hãy sử dụng tool `tom_tat_tien_do`.
7. Đừng chỉ trả về kết quả thô từ tool. Hãy trò chuyện!
"""
prompt = ChatPromptTemplate.from_messages([
    ("system", system_prompt_template),
    MessagesPlaceholder(variable_name="chat_history"),
    ("human", "USER_ID: {user_id}\n\nPROMPT: {input}"),
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
    input_messages_key="input",
    history_messages_key="chat_history",
    input_messages_and_history_passthrough=True,
)

# --- 6. API SERVER ---
app = FastAPI(title="Skedule AI Agent API", version="2.5.0 (Voice Confirmation)")

class ChatResponse(BaseModel):
    user_prompt: str | None = None # Thêm trường này để trả về lời người dùng nói
    text_response: str
    audio_base64: str

@app.get("/")
def read_root():
    return {"message": "Skedule AI Voice Agent is running!"}

@app.post("/chat", response_model=ChatResponse)
async def handle_chat_request(
    prompt: str | None = Form(None),
    audio_file: UploadFile | None = File(None),
    user_id: str = Depends(get_current_user_id)
):
    user_prompt = ""
    if audio_file:
        user_prompt = await audio_to_text(audio_file)
    elif prompt:
        user_prompt = prompt
    else:
        raise HTTPException(status_code=400, detail="Cần cung cấp prompt dạng văn bản hoặc file âm thanh.")

    session_id = f"user_{user_id}"
    print(f"📨 Prompt nhận từ user {user_id}: {user_prompt}")
    
    final_result = agent_with_chat_history.invoke(
        {"input": user_prompt, "user_id": user_id},
        config={"configurable": {"session_id": session_id}}
    )
    ai_text_response = final_result.get("output", "Lỗi: Không có phản hồi từ agent.")
    
    ai_audio_base64 = text_to_base64_audio(ai_text_response)
    
    return ChatResponse(
        user_prompt=user_prompt if audio_file else None, # Chỉ trả về khi input là audio
        text_response=ai_text_response,
        audio_base64=ai_audio_base64
    )

