package backend_iot_aquarium.backend_iot_aquarium.repository;

import backend_iot_aquarium.backend_iot_aquarium.model.Telemetry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TelemetryRepository extends JpaRepository<Telemetry, Long> {
    List<Telemetry> findTop100ByOrderByTimestampDesc();
    Telemetry findTopByOrderByTimestampDesc();
    List<Telemetry> findTop100ByPondIdOrderByTimestampDesc(Long pondId);
    Telemetry findTopByPondIdOrderByTimestampDesc(Long pondId);
}
