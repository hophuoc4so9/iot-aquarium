package backend_iot_aquarium.backend_iot_aquarium.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
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
        try {
            Map<String, Object> response = restTemplate.postForObject(url, entity, Map.class);
            if (response == null) {
                throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "AI service returned empty response");
            }
            return response;
        } catch (HttpStatusCodeException ex) {
            HttpStatus status = HttpStatus.resolve(ex.getStatusCode().value());
            if (status == null) {
                status = HttpStatus.BAD_GATEWAY;
            }
            String body = ex.getResponseBodyAsString();
            String reason = (body == null || body.isBlank()) ? "AI service error" : body;
            throw new ResponseStatusException(status, reason, ex);
        } catch (ResourceAccessException ex) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Cannot reach AI service", ex);
        }
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

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(body, headers);

        String url = baseUrl + "/ponds/" + pondId + "/alerts";
        try {
            Map<String, Object> response = restTemplate.postForObject(url, entity, Map.class);
            if (response == null) {
                throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "AI service returned empty response");
            }
            return response;
        } catch (HttpStatusCodeException ex) {
            HttpStatus status = HttpStatus.resolve(ex.getStatusCode().value());
            if (status == null) {
                status = HttpStatus.BAD_GATEWAY;
            }
            String responseBody = ex.getResponseBodyAsString();
            String reason = (responseBody == null || responseBody.isBlank())
                    ? "AI alerts service error"
                    : responseBody;
            throw new ResponseStatusException(status, reason, ex);
        } catch (ResourceAccessException ex) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Cannot reach AI service", ex);
        }
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> uploadFlUpdate(Map<String, Object> body) {
        Map<String, Object> normalized = new HashMap<>();
        normalized.put("deviceId", asInt(body.get("deviceId")));
        normalized.put("pondId", asInt(body.get("pondId")));
        normalized.put("roundId", asInt(body.get("roundId")));
        normalized.put("sampleCount", asInt(body.getOrDefault("sampleCount", 1)));
        normalized.put("loss", asDoubleNullable(body.get("loss")));
        normalized.put("shape", asIntList(body.get("shape")));
        normalized.put("weights", asDoubleList(body.get("weights")));

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(normalized, headers);
        return restTemplate.postForObject(baseUrl + "/fl/updates", entity, Map.class);
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> uploadFlReport(Map<String, Object> body) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(body, headers);
        return restTemplate.postForObject(baseUrl + "/fl/reports", entity, Map.class);
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> aggregateFlRound(Long roundId, int minClients, int minSamples) {
        Map<String, Object> body = new HashMap<>();
        body.put("roundId", roundId.intValue());
        body.put("minClients", minClients);
        body.put("minSamples", minSamples);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(body, headers);

        try {
            Map<String, Object> response = restTemplate.postForObject(baseUrl + "/fl/aggregate", entity, Map.class);
            if (response == null) {
                return errorResponse("AI aggregate returned empty response", HttpStatus.BAD_GATEWAY.value());
            }
            return response;
        } catch (HttpStatusCodeException ex) {
            return errorResponse(ex.getResponseBodyAsString(), ex.getStatusCode().value());
        } catch (ResourceAccessException ex) {
            return errorResponse("Cannot reach AI service", HttpStatus.SERVICE_UNAVAILABLE.value());
        }
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> getLatestFlModel() {
        try {
            Map<String, Object> response = restTemplate.getForObject(baseUrl + "/fl/models/latest", Map.class);
            if (response != null) {
                return response;
            }
        } catch (HttpStatusCodeException ex) {
            return errorResponse(nonBlank(ex.getResponseBodyAsString(), "No active global model"), ex.getStatusCode().value());
        } catch (ResourceAccessException ex) {
            return errorResponse("Cannot reach AI service", HttpStatus.SERVICE_UNAVAILABLE.value());
        }

        return errorResponse("No active global model", HttpStatus.NOT_FOUND.value());
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> getFlReports(long roundId) {
        try {
            Map<String, Object> response = restTemplate.getForObject(baseUrl + "/fl/reports/" + roundId, Map.class);
            if (response != null) {
                return response;
            }
        } catch (HttpStatusCodeException ex) {
            return Map.of(
                    "roundId", roundId,
                    "reports", List.of(),
                    "success", false,
                    "error", nonBlank(ex.getResponseBodyAsString(), "AI reports request failed"),
                    "statusCode", ex.getStatusCode().value()
            );
        } catch (ResourceAccessException ex) {
            return Map.of(
                    "roundId", roundId,
                    "reports", List.of(),
                    "success", false,
                    "error", "Cannot reach AI service",
                    "statusCode", HttpStatus.SERVICE_UNAVAILABLE.value()
            );
        }

        return Map.of(
                "roundId", roundId,
                "reports", List.of(),
                "success", true
        );
    }

    private Integer asInt(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Number number) {
            return number.intValue();
        }
        return Integer.parseInt(String.valueOf(value));
    }

    private Double asDoubleNullable(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Number number) {
            return number.doubleValue();
        }
        return Double.parseDouble(String.valueOf(value));
    }

    private List<Integer> asIntList(Object value) {
        if (!(value instanceof List<?> list)) {
            return List.of();
        }

        List<Integer> out = new ArrayList<>();
        for (Object item : list) {
            out.add(asInt(item));
        }
        return out;
    }

    private List<Double> asDoubleList(Object value) {
        if (!(value instanceof List<?> list)) {
            return List.of();
        }

        List<Double> out = new ArrayList<>();
        for (Object item : list) {
            out.add(asDoubleNullable(item));
        }
        return out;
    }

    private Map<String, Object> errorResponse(String error, int statusCode) {
        Map<String, Object> response = new HashMap<>();
        response.put("success", false);
        response.put("error", nonBlank(error, "AI request failed"));
        response.put("statusCode", statusCode);
        return response;
    }

    private String nonBlank(String value, String fallback) {
        if (value == null || value.isBlank()) {
            return fallback;
        }
        return value;
    }
}

