package backend_iot_aquarium.backend_iot_aquarium.model;

import jakarta.persistence.*;
import java.time.Instant;

/**
 * Lưu từng tin nhắn trong phiên chat (user hoặc assistant).
 * Admin có thể xem lịch sử tại web-admin.
 */
@Entity
@Table(name = "chat_message", indexes = @Index(name = "idx_chat_session", columnList = "sessionId"))
public class ChatMessage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 64)
    private String sessionId;

    /** user | assistant */
    @Column(nullable = false, length = 20)
    private String role;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(nullable = false)
    private Instant createdAt;

    /** Optional: identifier từ app (userId/deviceId) để admin filter */
    @Column(length = 128)
    private String clientId;

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) createdAt = Instant.now();
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getSessionId() { return sessionId; }
    public void setSessionId(String sessionId) { this.sessionId = sessionId; }
    public String getRole() { return role; }
    public void setRole(String role) { this.role = role; }
    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
    public String getClientId() { return clientId; }
    public void setClientId(String clientId) { this.clientId = clientId; }
}
