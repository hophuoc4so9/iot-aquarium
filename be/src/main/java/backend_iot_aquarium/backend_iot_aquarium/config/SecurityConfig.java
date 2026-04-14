package backend_iot_aquarium.backend_iot_aquarium.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

/**
 * Cấu hình bảo mật:
 * - Cho phép truy cập không cần auth tới WebSocket, telemetry/control, AI, chat (demo).
 * - Bật HTTP Basic dùng UserAccount trong DB cho các đường dẫn cần bảo vệ.
 * - Bật CORS để Flutter web (Chrome, localhost:* ) và web-admin truy cập được.
 */
@Configuration
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                .csrf(csrf -> csrf.disable())
                .cors(Customizer.withDefaults())
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/ws/**").permitAll()
                        .requestMatchers("/api/telemetry/**").permitAll()
                        .requestMatchers("/api/control/**").permitAll()
                        .requestMatchers("/api/fl/**").permitAll()
                        .requestMatchers("/api/ai/fish-disease/history", "/api/ai/fish-disease/history/**").authenticated()
                        .requestMatchers("/api/ai/**").permitAll()
                        .requestMatchers("/api/chat/**").permitAll()
                        .requestMatchers("/api/auth/**").permitAll()
                        .requestMatchers("/actuator/**").permitAll()
                        // Cho phép gọi import dataset không cần đăng nhập (dev)
                        .requestMatchers("/api/admin/fish/import").permitAll()
                        // Các API admin khác yêu cầu role ADMIN
                        .requestMatchers("/api/admin/**").hasRole("ADMIN")
                        // API ao cho app-user: cần đăng nhập
                        .requestMatchers("/api/ponds/**").authenticated()
                        .anyRequest().permitAll()
                )
                .httpBasic(Customizer.withDefaults());

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    /**
     * CORS global: cho phép tất cả origin/method/header (phù hợp cho môi trường dev/demo).
     * Khi lên production nên thu hẹp lại theo domain cụ thể.
     */
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        configuration.setAllowedOriginPatterns(List.of("*"));
        configuration.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        configuration.setAllowedHeaders(List.of("*"));
        configuration.setAllowCredentials(false);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }
}

