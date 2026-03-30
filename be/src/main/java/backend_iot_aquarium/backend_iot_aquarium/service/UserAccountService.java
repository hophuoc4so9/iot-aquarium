package backend_iot_aquarium.backend_iot_aquarium.service;

import backend_iot_aquarium.backend_iot_aquarium.model.UserAccount;
import backend_iot_aquarium.backend_iot_aquarium.repository.UserAccountRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
public class UserAccountService {

    private final UserAccountRepository userAccountRepository;
    private final PasswordEncoder passwordEncoder;

    public UserAccountService(UserAccountRepository userAccountRepository,
                              PasswordEncoder passwordEncoder) {
        this.userAccountRepository = userAccountRepository;
        this.passwordEncoder = passwordEncoder;
    }

    public boolean usernameExists(String username) {
        return userAccountRepository.existsByUsername(username);
    }

    public UserAccount registerUser(String username, String rawPassword, String fullName) {
        UserAccount user = new UserAccount();
        user.setUsername(username);
        user.setPasswordHash(passwordEncoder.encode(rawPassword));
        user.setRole("USER");
        user.setFullName(fullName);
        return userAccountRepository.save(user);
    }

    public Optional<UserAccount> findByUsername(String username) {
        return userAccountRepository.findByUsername(username);
    }

    public UserAccount registerAdmin(String username, String rawPassword, String fullName) {
        UserAccount user = new UserAccount();
        user.setUsername(username);
        user.setPasswordHash(passwordEncoder.encode(rawPassword));
        user.setRole("ADMIN");
        user.setFullName(fullName);
        return userAccountRepository.save(user);
    }

    public UserAccount createAdminIfNotExists(String username, String rawPassword) {
        return userAccountRepository.findByUsername(username)
                .orElseGet(() -> {
                    UserAccount admin = new UserAccount();
                    admin.setUsername(username);
                    admin.setPasswordHash(passwordEncoder.encode(rawPassword));
                    admin.setRole("ADMIN");
                    admin.setFullName("Admin");
                    return userAccountRepository.save(admin);
                });
    }
}

