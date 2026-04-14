package backend_iot_aquarium.backend_iot_aquarium;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class BackendIotAquariumApplication {

	public static void main(String[] args) {
		SpringApplication.run(BackendIotAquariumApplication.class, args);
	}

}
