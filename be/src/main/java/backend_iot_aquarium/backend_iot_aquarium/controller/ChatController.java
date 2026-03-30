package backend_iot_aquarium.backend_iot_aquarium.controller;

import backend_iot_aquarium.backend_iot_aquarium.model.ChatMessage;
import backend_iot_aquarium.backend_iot_aquarium.service.GeminiChatService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Chatbot tư vấn: app-user gửi tin, backend gọi Gemini và lưu lịch sử.
 * Admin xem lịch sử tại web-admin.
 */
@RestController
@RequestMapping("/api/chat")
@CrossOrigin(origins = "*")
public class ChatController {

    private final GeminiChatService geminiChatService;

    public ChatController(GeminiChatService geminiChatService) {
        this.geminiChatService = geminiChatService;
    }

    /** App-user gửi tin nhắn, nhận reply từ AI. */
    @PostMapping
    public ResponseEntity<Map<String, Object>> sendMessage(@RequestBody Map<String, String> body) {
        String sessionId = body.getOrDefault("sessionId", "default");
        String message = body.getOrDefault("message", "");
        String clientId = body.getOrDefault("clientId", "");

        if (message.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "message is required"));
        }

        String reply = geminiChatService.chat(sessionId, message.trim(), clientId);
        Map<String, Object> result = new HashMap<>();
        result.put("reply", reply);
        result.put("sessionId", sessionId);
        return ResponseEntity.ok(result);
    }

    /** Lấy lịch sử chat của một phiên (app-user hoặc admin). */
    @GetMapping("/history")
    public ResponseEntity<List<Map<String, Object>>> getHistory(@RequestParam String sessionId) {
        List<ChatMessage> list = geminiChatService.getHistory(sessionId);
        List<Map<String, Object>> dto = list.stream().map(m -> {
            Map<String, Object> map = new HashMap<>();
            map.put("id", m.getId());
            map.put("role", m.getRole());
            map.put("content", m.getContent());
            map.put("createdAt", m.getCreatedAt() != null ? m.getCreatedAt().toString() : null);
            map.put("clientId", m.getClientId());
            return map;
        }).collect(Collectors.toList());
        return ResponseEntity.ok(dto);
    }

    /** Admin: danh sách tất cả session. */
    @GetMapping("/sessions")
    public ResponseEntity<List<String>> listSessions() {
        return ResponseEntity.ok(geminiChatService.getAllSessionIds());
    }
}
