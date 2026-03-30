package backend_iot_aquarium.backend_iot_aquarium.repository;

import backend_iot_aquarium.backend_iot_aquarium.model.FishSpecies;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface FishSpeciesRepository extends JpaRepository<FishSpecies, Long> {

    /**
     * Search fish by English or Vietnamese name (case-insensitive)
     */
    @Query("SELECT f FROM FishSpecies f WHERE " +
           "LOWER(f.nameEnglish) LIKE LOWER(CONCAT('%', :searchTerm, '%')) OR " +
           "LOWER(f.nameVietnamese) LIKE LOWER(CONCAT('%', :searchTerm, '%'))")
    List<FishSpecies> searchByName(@Param("searchTerm") String searchTerm);

    /**
     * Find all active fish species with both temperature and pH range data
     */
    @Query("SELECT f FROM FishSpecies f WHERE " +
           "f.isActive = true AND " +
           "f.tempRange IS NOT NULL AND f.tempRange != '' AND " +
           "f.phRange IS NOT NULL AND f.phRange != '' " +
           "ORDER BY f.nameEnglish")
    List<FishSpecies> findAllActiveWithCompleteData();

    /**
     * Find fish by English name
     */
    Optional<FishSpecies> findByNameEnglish(String nameEnglish);

    /**
     * Find all active fish species
     */
    List<FishSpecies> findByIsActiveTrueOrderByNameEnglish();

    /**
     * Search with complete data only
     */
    @Query("SELECT f FROM FishSpecies f WHERE " +
           "f.isActive = true AND " +
           "f.tempRange IS NOT NULL AND f.tempRange != '' AND " +
           "f.phRange IS NOT NULL AND f.phRange != '' AND " +
           "(LOWER(f.nameEnglish) LIKE LOWER(CONCAT('%', :searchTerm, '%')) OR " +
           "LOWER(f.nameVietnamese) LIKE LOWER(CONCAT('%', :searchTerm, '%'))) " +
           "ORDER BY f.nameEnglish")
    List<FishSpecies> searchByNameWithCompleteData(@Param("searchTerm") String searchTerm);

    /**
     * All active fish species that already have some temperature/pH information
     * (auto/custom ranges or raw range strings), dùng cho trang cấu hình ngưỡng.
     * Có hỗ trợ lọc theo tên (EN/VN, không phân biệt hoa thường).
     */
    @Query("""
           SELECT f FROM FishSpecies f
           WHERE f.isActive = true
             AND (
               (f.autoTempMin IS NOT NULL AND f.autoTempMax IS NOT NULL) OR
               (f.autoPhMin IS NOT NULL AND f.autoPhMax IS NOT NULL) OR
               (f.customTempMin IS NOT NULL AND f.customTempMax IS NOT NULL) OR
               (f.customPhMin IS NOT NULL AND f.customPhMax IS NOT NULL) OR
               (f.tempRange IS NOT NULL AND f.tempRange <> '') OR
               (f.phRange IS NOT NULL AND f.phRange <> '')
             )
             AND (
               :searchTerm IS NULL
               OR :searchTerm = ''
               OR LOWER(f.nameEnglish) LIKE LOWER(CONCAT('%', :searchTerm, '%'))
               OR LOWER(f.nameVietnamese) LIKE LOWER(CONCAT('%', :searchTerm, '%'))
             )
           ORDER BY f.nameEnglish
           """)
    Page<FishSpecies> findConfiguredFishWithRanges(@Param("searchTerm") String searchTerm,
                                                   Pageable pageable);

    /**
     * Find by SpecCode (FishBase)
     */
    Optional<FishSpecies> findBySpecCode(Integer specCode);

    /**
     * Find by normalized name key (for aquarium CSV join)
     */
    Optional<FishSpecies> findFirstByNameKey(String nameKey);
}
