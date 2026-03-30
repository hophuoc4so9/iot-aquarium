package backend_iot_aquarium.backend_iot_aquarium.service;

import backend_iot_aquarium.backend_iot_aquarium.model.ChatMessage;
import backend_iot_aquarium.backend_iot_aquarium.repository.ChatMessageRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.List;
import java.util.stream.Collectors;

/**
 * Cấu hình: gemini.api.key trong application.properties hoặc env GEMINI_API_KEY.
 */
@Service
public class GeminiChatService {

    private static final String GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models/";
    private static final String SYSTEM_HINT = "Bạn là trợ lý tư vấn chăm sóc cá và nuôi trồng thủy sản. Trả lời ngắn gọn, hữu ích bằng tiếng Việt. Nếu hỏi về nhiệt độ, pH, mực nước thì gợi ý khoảng an toàn chung.";

    private final ChatMessageRepository chatMessageRepository;
    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper mapper = new ObjectMapper();

    @Value("${gemini.api.key:}")
    private String apiKey;

    @Value("${gemini.model:gemini-2.5-flash}")
    private String model;

    public GeminiChatService(ChatMessageRepository chatMessageRepository) {
        this.chatMessageRepository = chatMessageRepository;
    }

    /** Gửi tin nhắn user, gọi Gemini, lưu cả user + assistant, trả về reply. */
    public String chat(String sessionId, String userMessage, String clientId) {
        if (apiKey == null || apiKey.isBlank()) {
            return "Chưa cấu hình Gemini API key. Admin vui lòng thêm gemini.api.key trong application.properties hoặc biến môi trường GEMINI_API_KEY.";
        }

        // Lấy lịch sử trước (để context), rồi mới lưu tin user
        List<ChatMessage> history = chatMessageRepository.findBySessionIdOrderByCreatedAtAsc(sessionId);
        String reply = callGemini(history, userMessage);

        // Lưu tin nhắn user
        ChatMessage userMsg = new ChatMessage();
        userMsg.setSessionId(sessionId);
        userMsg.setRole("user");
        userMsg.setContent(userMessage);
        userMsg.setClientId(clientId);
        chatMessageRepository.save(userMsg);

        // Lưu tin nhắn assistant
        ChatMessage assistantMsg = new ChatMessage();
        assistantMsg.setSessionId(sessionId);
        assistantMsg.setRole("assistant");
        assistantMsg.setContent(reply);
        assistantMsg.setClientId(clientId);
        chatMessageRepository.save(assistantMsg);

        return reply;
    }

    private String callGemini(List<ChatMessage> history, String lastUserMessage) {
        try {
            ObjectNode root = mapper.createObjectNode();
            ArrayNode contents = root.putArray("contents");
            // systemInstruction: Content object (parts[].text)
            ObjectNode sysInstr = mapper.createObjectNode();
            sysInstr.putArray("parts").addObject().put("text", SYSTEM_HINT);
            root.set("systemInstruction", sysInstr);

            // Gửi tối đa 20 tin gần nhất làm context (trừ tin vừa gửi đã nằm trong lastUserMessage)
            int from = Math.max(0, history.size() - 20);
            for (int i = from; i < history.size(); i++) {
                ChatMessage m = history.get(i);
                ObjectNode content = contents.addObject();
                content.put("role", "user".equals(m.getRole()) ? "user" : "model");
                ArrayNode parts = content.putArray("parts");
                parts.addObject().put("text", m.getContent());
            }
            // Tin hiện tại
            ObjectNode last = contents.addObject();
            last.put("role", "user");
            last.putArray("parts").addObject().put("text", lastUserMessage);

            String modelName = (model == null || model.isBlank()) ? "gemini-2.5-flash" : model.trim();
            String url = GEMINI_BASE + modelName + ":generateContent?key=" + apiKey.trim();
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            ResponseEntity<String> res = restTemplate.exchange(
                    url,
                    HttpMethod.POST,
                    new HttpEntity<>(mapper.writeValueAsString(root), headers),
                    String.class
            );

            if (res.getStatusCode().is2xxSuccessful() && res.getBody() != null) {
                JsonNode body = mapper.readTree(res.getBody());
                JsonNode candidates = body.path("candidates");
                if (candidates.isArray() && candidates.size() > 0) {
                    JsonNode content = candidates.get(0).path("content").path("parts");
                    if (content.isArray() && content.size() > 0) {
                        return content.get(0).path("text").asText("");
                    }
                }
            }
        } catch (Exception e) {
            return "Lỗi khi gọi trợ lý AI: " + e.getMessage();
        }
        return "Không nhận được phản hồi từ AI.";
    }

    public List<ChatMessage> getHistory(String sessionId) {
        return chatMessageRepository.findBySessionIdOrderByCreatedAtAsc(sessionId);
    }

    public List<String> getAllSessionIds() {
        return chatMessageRepository.findDistinctSessionIds();
    }
}
