package backend_iot_aquarium.backend_iot_aquarium.repository;

import backend_iot_aquarium.backend_iot_aquarium.model.ChatMessage;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {

    List<ChatMessage> findBySessionIdOrderByCreatedAtAsc(String sessionId);

    /** Lấy danh sách session_id phân biệt (để admin xem danh sách phiên). */
    @org.springframework.data.jpa.repository.Query("SELECT DISTINCT c.sessionId FROM ChatMessage c ORDER BY c.sessionId")
    List<String> findDistinctSessionIds();
}
