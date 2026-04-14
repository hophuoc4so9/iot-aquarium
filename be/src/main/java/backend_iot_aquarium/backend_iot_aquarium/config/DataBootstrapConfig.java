package backend_iot_aquarium.backend_iot_aquarium.config;

import backend_iot_aquarium.backend_iot_aquarium.service.UserAccountService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class DataBootstrapConfig {

    @Bean
    public CommandLineRunner bootstrapDefaultUsers(
            UserAccountService userAccountService,
            @Value("${app.bootstrap.users.enabled:true}") boolean enabled,
            @Value("${app.bootstrap.admin.username:admin}") String adminUsername,
            @Value("${app.bootstrap.admin.password:123456}") String adminPassword,
            @Value("${app.bootstrap.user.username:farmer1}") String userUsername,
            @Value("${app.bootstrap.user.password:123456}") String userPassword,
            @Value("${app.bootstrap.user.full-name:Farmer 1}") String userFullName
    ) {
        return args -> {
            if (!enabled) {
                return;
            }

            userAccountService.createAdminIfNotExists(adminUsername, adminPassword);
            userAccountService.createUserIfNotExists(userUsername, userPassword, userFullName);
        };
    }
}
