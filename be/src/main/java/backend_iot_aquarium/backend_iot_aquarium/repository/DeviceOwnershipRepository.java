package backend_iot_aquarium.backend_iot_aquarium.repository;

import backend_iot_aquarium.backend_iot_aquarium.model.DeviceOwnership;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface DeviceOwnershipRepository extends JpaRepository<DeviceOwnership, Long> {
    Optional<DeviceOwnership> findByDeviceId(Long deviceId);
    List<DeviceOwnership> findByOwnerUsername(String ownerUsername);
}
