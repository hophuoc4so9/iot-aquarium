package backend_iot_aquarium.backend_iot_aquarium.repository;

import backend_iot_aquarium.backend_iot_aquarium.model.Pond;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PondRepository extends JpaRepository<Pond, Long> {

    java.util.List<Pond> findByOwnerUsername(String ownerUsername);

    boolean existsByIdAndOwnerUsername(Long id, String ownerUsername);
}

