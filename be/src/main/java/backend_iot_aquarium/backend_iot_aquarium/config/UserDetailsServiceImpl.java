package backend_iot_aquarium.backend_iot_aquarium.config;

import backend_iot_aquarium.backend_iot_aquarium.model.UserAccount;
import backend_iot_aquarium.backend_iot_aquarium.repository.UserAccountRepository;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class UserDetailsServiceImpl implements UserDetailsService {

    private final UserAccountRepository userAccountRepository;

    public UserDetailsServiceImpl(UserAccountRepository userAccountRepository) {
        this.userAccountRepository = userAccountRepository;
    }

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        UserAccount user = userAccountRepository.findByUsername(username)
                .orElseThrow(() -> new UsernameNotFoundException("User not found: " + username));

        String role = user.getRole() != null ? user.getRole() : "USER";
        GrantedAuthority authority = new SimpleGrantedAuthority("ROLE_" + role);

        return new User(
                user.getUsername(),
                user.getPasswordHash(),
                List.of(authority)
        );
    }
}

