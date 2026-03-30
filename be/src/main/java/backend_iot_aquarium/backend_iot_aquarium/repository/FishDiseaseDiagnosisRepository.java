package backend_iot_aquarium.backend_iot_aquarium.repository;

import backend_iot_aquarium.backend_iot_aquarium.model.FishDiseaseDiagnosis;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface FishDiseaseDiagnosisRepository extends JpaRepository<FishDiseaseDiagnosis, Long> {

    List<FishDiseaseDiagnosis> findByUsernameOrderByDiagnosedAtDesc(String username);

    List<FishDiseaseDiagnosis> findByUsernameAndPondIdOrderByDiagnosedAtDesc(String username, Long pondId);
}
