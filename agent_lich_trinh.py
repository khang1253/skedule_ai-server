import os
import json
from dotenv import load_dotenv
from datetime import date, timedelta, datetime

from langchain_core.messages import HumanMessage
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain.tools import tool
from langchain.agents import AgentExecutor, create_tool_calling_agent
from sqlalchemy import create_engine, text, Connection
from sqlalchemy.engine.base import Engine

# --- 1. CẤU HÌNH VÀ KẾT NỐI DATABASE ---

load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
# Chỉ lấy giá trị từ file .env
DATABASE_URL = os.getenv("DATABASE_URL")

# Thêm dòng này để kiểm tra xem đã load được chưa, nếu chưa thì báo lỗi ngay
if not DATABASE_URL:
    raise ValueError(
        "Lỗi: Không tìm thấy hoặc không đọc được biến DATABASE_URL từ file .env")

# Khởi tạo kết nối Database theo đặc tả
engine: Engine = create_engine(DATABASE_URL)

# Hàm trợ giúp để lấy giá trị key linh hoạt


def get_flexible_arg(args, key, default=None):
    """Kiểm tra key chữ thường, sau đó là chữ hoa đầu."""
    return args.get(key, args.get(key.capitalize(), default))


# Khởi tạo mô hình ngôn ngữ
llm_brain = ChatGoogleGenerativeAI(
    model="gemini-2.5-flash",  # Sử dụng model mới hơn nếu có thể
    google_api_key=GEMINI_API_KEY,
    temperature=0
)

# --- 2. ĐỊNH NGHĨA CÔNG CỤ (TOOLS) ĐÃ ĐƯỢC CẬP NHẬT ---

# LƯU Ý: user_id đang được gán cứng là 1 cho mục đích demo.
# Trong thực tế, bạn cần một cơ chế xác thực để lấy user_id động.
CURRENT_USER_ID = 1


@tool
def tao_task_va_len_lich(input: str) -> str:
    """
    Sử dụng công cụ này khi người dùng muốn TẠO, THÊM, hoặc LÊN LỊCH một công việc/sự kiện MỚI.
    Công cụ này sẽ tạo một 'task' và sau đó gắn nó vào một 'schedule' trên lịch.
    Đầu vào: Chuỗi JSON chứa 'tieu_de', 'thoi_gian_bat_dau' (YYYY-MM-DD HH:MM:SS), và 'thoi_gian_ket_thuc' (YYYY-MM-DD HH:MM:SS).
    """
    try:
        args = json.loads(input)
        tieu_de = get_flexible_arg(args, "tieu_de", "Công việc mới")
        start_time_str = get_flexible_arg(args, "thoi_gian_bat_dau")
        end_time_str = get_flexible_arg(args, "thoi_gian_ket_thuc")

        if not all([tieu_de, start_time_str, end_time_str]):
            return "❌ Lỗi: Thiếu thông tin 'tieu_de', 'thoi_gian_bat_dau', hoặc 'thoi_gian_ket_thuc'."

        with engine.connect() as connection:
            # Bắt đầu một transaction để đảm bảo cả hai hành động cùng thành công
            with connection.begin() as transaction:
                try:
                    # 1. Tạo task mới trong bảng `tasks` và lấy task_id
                    task_query = text(
                        "INSERT INTO tasks (user_id, title) VALUES (:user_id, :title) RETURNING id;"
                    )
                    result = connection.execute(
                        task_query, {"user_id": CURRENT_USER_ID, "title": tieu_de})
                    task_id = result.scalar_one_or_none()

                    if not task_id:
                        raise Exception("Không thể tạo task mới.")

                    # 2. Tạo lịch trình trong bảng `schedules` với task_id vừa nhận được
                    schedule_query = text(
                        """
                        INSERT INTO schedules (user_id, task_id, start_time, end_time)
                        VALUES (:user_id, :task_id, :start_time, :end_time);
                        """
                    )
                    connection.execute(
                        schedule_query,
                        {
                            "user_id": CURRENT_USER_ID,
                            "task_id": task_id,
                            "start_time": start_time_str,
                            "end_time": end_time_str,
                        },
                    )
                    transaction.commit()  # Hoàn tất transaction
                    return f"✅ Đã lên lịch '{tieu_de}' từ {start_time_str} đến {end_time_str} thành công!"
                except Exception as e:
                    transaction.rollback()  # Hoàn tác nếu có lỗi
                    return f"❌ Lỗi khi thực hiện giao dịch CSDL: {e}"

    except Exception as e:
        return f"❌ Lỗi thực thi TẠO: Lỗi DB hoặc tham số JSON: {e}"


@tool
def xoa_task_theo_lich(input: str) -> str:
    """
    Sử dụng công cụ này khi người dùng muốn XÓA, HỦY hoặc LOẠI BỎ một công việc/sự kiện đã có.
    Đầu vào: Chuỗi JSON chứa 'tieu_de' để xác định công việc cần xóa.
    """
    try:
        args = json.loads(input)
        tieu_de = get_flexible_arg(args, "tieu_de")
        if not tieu_de:
            return "❌ Vui lòng cung cấp tiêu đề của sự kiện cần xóa."

        with engine.connect() as connection:
            with connection.begin() as transaction:
                # Xóa task sẽ tự động xóa schedule liên quan nhờ `ON DELETE CASCADE`
                query = text(
                    "DELETE FROM tasks WHERE title = :title AND user_id = :user_id;")
                result = connection.execute(
                    query, {"title": tieu_de, "user_id": CURRENT_USER_ID})
                transaction.commit()

                if result.rowcount > 0:
                    return f"🗑️ Đã xóa thành công công việc '{tieu_de}' và lịch trình liên quan."
                else:
                    return f"⚠️ Không tìm thấy công việc nào có tên '{tieu_de}' để xóa."
    except Exception as e:
        return f"❌ Lỗi thực thi XÓA: {e}"


@tool
def tim_lich_trinh(input: str) -> str:
    """
    Sử dụng công cụ này khi người dùng muốn TÌM KIẾM, XEM hoặc LIỆT KÊ các sự kiện trong một khoảng thời gian.
    Đầu vào: Chuỗi JSON chứa 'ngay_bat_dau' (YYYY-MM-DD) và 'ngay_ket_thuc' (YYYY-MM-DD).
    """
    try:
        args = json.loads(input)
        start_date = get_flexible_arg(args, 'ngay_bat_dau', str(date.today()))
        end_date = get_flexible_arg(
            args, 'ngay_ket_thuc', str(date.today() + timedelta(days=7)))

        with engine.connect() as connection:
            # JOIN 2 bảng `schedules` và `tasks` để lấy thông tin
            query = text(
                """
                SELECT t.title, s.start_time, s.end_time
                FROM schedules s
                JOIN tasks t ON s.task_id = t.id
                WHERE s.user_id = :user_id
                  AND s.start_time::date BETWEEN :start_date AND :end_date
                ORDER BY s.start_time
                LIMIT 10;
                """
            )
            results = connection.execute(
                query, {"user_id": CURRENT_USER_ID,
                        "start_date": start_date, "end_date": end_date}
            ).fetchall()

            if results:
                events = [
                    f"('{row.title}', từ '{row.start_time.strftime('%Y-%m-%d %H:%M')}' đến '{row.end_time.strftime('%Y-%m-%d %H:%M')}')"
                    for row in results
                ]
                return f"🔎 Đã tìm thấy {len(events)} sự kiện: {'; '.join(events)}"
            else:
                return f"📭 Không tìm thấy sự kiện nào từ {start_date} đến {end_date}."

    except Exception as e:
        return f"❌ Lỗi thực thi TÌM KIẾM: {e}"


# --- 3. LẮP RÁP LOGIC AGENT ---

tools_list = [tao_task_va_len_lich, xoa_task_theo_lich, tim_lich_trinh]

system_prompt_template = (
    "Bạn là một trợ lý AI chuyên quản lý lịch trình cho ứng dụng Skedule. "
    "Nhiệm vụ của bạn là phân tích yêu cầu của người dùng và SỬ DỤNG CÁC CÔNG CỤ được cung cấp để thực hiện hành động. "
    "Luôn luôn hành động ngay lập tức khi một công cụ có thể được sử dụng. "
    "QUY TẮC BẮT BUỘC:\n"
    "1. NGÀY GIỜ: PHẢI sử dụng định dạng 'YYYY-MM-DD HH:MM:SS' khi gọi công cụ tạo lịch. "
    "   Nếu người dùng không cung cấp giờ, hãy giả định giờ làm việc mặc định (ví dụ: bắt đầu lúc 09:00:00, kết thúc lúc 10:00:00).\n"
    "2. NĂM: Luôn giả định năm hiện tại là 2025 nếu không được chỉ định.\n"
    "3. HÀNH ĐỘNG: Phân tích kỹ yêu cầu để chọn đúng công cụ: 'tao_task_va_len_lich' cho việc tạo mới, "
    "'xoa_task_theo_lich' cho việc hủy bỏ, và 'tim_lich_trinh' cho việc xem/liệt kê.\n"
    "4. PHẠM VI NGÀY: Khi người dùng nói 'Tuần sau' (Hôm nay là Thứ Năm, 09/10/2025), "
    "   bạn PHẢI tính toán và truyền ngày chính xác: ngay_bat_dau='2025-10-13' (Thứ Hai) và ngay_ket_thuc='2025-10-19' (Chủ Nhật).\n"
    "5. Luôn phản hồi cuối cùng bằng Tiếng Việt."
)

prompt = ChatPromptTemplate.from_messages([
    ("system", system_prompt_template),
    MessagesPlaceholder(variable_name="chat_history", optional=True),
    ("human", "{input}"),
    MessagesPlaceholder(variable_name="agent_scratchpad"),
])

agent = create_tool_calling_agent(llm_brain, tools_list, prompt)
agent_executor = AgentExecutor(
    agent=agent,
    tools=tools_list,
    verbose=True
)

# --- 4. CHẠY THỬ NGHIỆM ---

# Test 1: Tạo task và lịch trình
# user_request = "Tạo cho tôi một task 'Hoàn thành báo cáo' vào 3 giờ chiều ngày mai"
# Test 2: Tìm kiếm lịch trình
# user_request = "Tuần sau tôi có công việc gì không?"
user_request = "Tạo một lịch hẹn 'Gặp khách hàng' vào 10 giờ sáng thứ ba tuần tới"
# Test 3: Xóa task
# user_request = "Hủy cuộc họp 'Hoàn thành báo cáo' đi"

print(f"\n=======================================================")
print(f"[NGƯỜI DÙNG] {user_request}")
print(f"=======================================================")

final_result = agent_executor.invoke({"input": user_request})

print("\n[✅ Kết quả cuối cùng]")
print(final_result.get("output", "Lỗi: Không tìm thấy phản hồi cuối cùng"))
