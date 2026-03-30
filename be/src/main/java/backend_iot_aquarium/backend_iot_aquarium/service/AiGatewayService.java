package backend_iot_aquarium.backend_iot_aquarium.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

/**
 * Gateway đơn giản gọi sang AI service (Python).
 * RestClient cho forecast / alerts; RestTemplate cho multipart (fish-disease).
 */
@Service
public class AiGatewayService {

    private final RestClient restClient;
    private final RestTemplate restTemplate;
    private final String baseUrl;

    public AiGatewayService(@Value("${ai.service.base-url}") String baseUrl) {
        this.baseUrl = baseUrl.replaceAll("/$", "");
        this.restClient = RestClient.builder()
                .baseUrl(this.baseUrl)
                .build();
        this.restTemplate = new RestTemplate();
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> forecast(Long pondId, String metric, int horizonHours) {
        Map<String, Object> body = new HashMap<>();
        body.put("pondId", pondId);
        body.put("metric", metric);
        body.put("horizonHours", horizonHours);

        return restClient.post()
                .uri("/forecast")
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .body(Map.class);
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> classifyFishDisease(Long pondId, MultipartFile file) {
        MultiValueMap<String, Object> parts = new LinkedMultiValueMap<>();
        byte[] bytes;
        try {
            bytes = file.getBytes();
        } catch (IOException e) {
            throw new RuntimeException("Failed to read uploaded file", e);
        }
        if (bytes.length == 0) {
            throw new IllegalArgumentException("Uploaded file is empty");
        }
        ByteArrayResource resource = new ByteArrayResource(bytes) {
            @Override
            public String getFilename() {
                return file.getOriginalFilename() != null ? file.getOriginalFilename() : "image";
            }
        };
        parts.add("file", resource);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);
        HttpEntity<MultiValueMap<String, Object>> entity = new HttpEntity<>(parts, headers);

        String url = baseUrl + "/fish-disease" + (pondId != null ? "?pondId=" + pondId : "");
        return restTemplate.postForObject(url, entity, Map.class);
    }

    /**
     * Gọi AI service để lấy cảnh báo tức thời cho 1 ao.
     * pondThresholds / fishThresholds có thể là null (AI sẽ tự fallback).
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> instantAlerts(Long pondId,
                                             Map<String, Object> pondThresholds,
                                             Map<String, Object> fishThresholds) {
        Map<String, Object> body = new HashMap<>();
        body.put("pondThresholds", pondThresholds);
        body.put("fishThresholds", fishThresholds);

        return restClient.post()
                .uri("/ponds/{pondId}/alerts", pondId)
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .body(Map.class);
    }
}

