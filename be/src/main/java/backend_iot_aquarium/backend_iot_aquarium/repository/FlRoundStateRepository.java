package backend_iot_aquarium.backend_iot_aquarium.repository;

import backend_iot_aquarium.backend_iot_aquarium.model.FlRoundStateEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface FlRoundStateRepository extends JpaRepository<FlRoundStateEntity, Long> {
    void deleteByRoundId(long roundId);
}