package backend_iot_aquarium.backend_iot_aquarium.repository;

import backend_iot_aquarium.backend_iot_aquarium.model.FishDatasetFile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface FishDatasetFileRepository extends JpaRepository<FishDatasetFile, Long> {

    Optional<FishDatasetFile> findByFileName(String fileName);
}

