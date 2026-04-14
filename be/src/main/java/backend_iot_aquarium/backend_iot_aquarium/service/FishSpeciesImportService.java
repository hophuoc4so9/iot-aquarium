package backend_iot_aquarium.backend_iot_aquarium.service;

import backend_iot_aquarium.backend_iot_aquarium.model.FishDatasetFile;
import backend_iot_aquarium.backend_iot_aquarium.model.FishSpecies;
import backend_iot_aquarium.backend_iot_aquarium.repository.FishDatasetFileRepository;
import backend_iot_aquarium.backend_iot_aquarium.repository.FishSpeciesRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.opencsv.CSVReader;
import com.opencsv.CSVReaderBuilder;
import com.opencsv.exceptions.CsvValidationException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.IOException;
import java.io.Reader;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.*;

/**
 * Import fish species data from CSV files into the database.
 * Uses vn_fish_species_info_vi.csv as the main source.
 */
@Service
public class FishSpeciesImportService {

    private final FishSpeciesRepository fishSpeciesRepository;
    private final FishDatasetFileRepository fishDatasetFileRepository;
    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * Path to vn_fish_species_info_vi.csv.
     * Default: classpath:data/vn_fish_species_info_vi.csv
     */
    @Value("${fish.csv.species-info:classpath:data/vn_fish_species_info_vi.csv}")
    private String speciesInfoCsvPath;

    /**
     * Path to vn_fish_species_info.csv (English/base info).
     * Default: classpath:data/vn_fish_species_info.csv
     */
    @Value("${fish.csv.species-base:classpath:data/vn_fish_species_info.csv}")
    private String speciesBaseCsvPath;

    /**
     * Path to vn_fish_ecology_vi.csv (ecology + Vietnamese description).
     * Default: classpath:data/vn_fish_ecology_vi.csv
     */
    @Value("${fish.csv.ecology-vi:classpath:data/vn_fish_ecology_vi.csv}")
    private String ecologyViCsvPath;

    /**
     * Path to vn_fish_ecology.csv (ecology/base English rows).
     * Default: classpath:data/vn_fish_ecology.csv
     */
    @Value("${fish.csv.ecology-base:classpath:data/vn_fish_ecology.csv}")
    private String ecologyBaseCsvPath;

    /**
     * Path to freshwater_aquarium_fish_species.csv (aquarium ranges by common name)
     * Default: classpath:data/freshwater_aquarium_fish_species.csv
     */
    @Value("${fish.csv.aquarium:classpath:data/freshwater_aquarium_fish_species.csv}")
    private String aquariumCsvPath;

    /**
     * Path to vn_fish_species_list.csv (country-specific presence for Vietnam)
     * Default: classpath:data/vn_fish_species_list.csv
     */
    @Value("${fish.csv.species-list:classpath:data/vn_fish_species_list.csv}")
    private String speciesListCsvPath;

    public FishSpeciesImportService(FishSpeciesRepository fishSpeciesRepository,
                                    FishDatasetFileRepository fishDatasetFileRepository) {
        this.fishSpeciesRepository = fishSpeciesRepository;
        this.fishDatasetFileRepository = fishDatasetFileRepository;
    }

    @Transactional
    public void importAllFromCsv() throws IOException {
        // Base English info (optional but useful to fill missing EN data)
        importSpeciesBaseInfo();
        // Ecology/base English remarks
        importEcologyBase();
        // Vietnamese names + remarks + images
        importSpeciesInfoVi();
        // Ecology (Vietnamese condition description)
        importEcologyVi();

        // Vietnam species list (distribution/status)
        importSpeciesListVietNam();

        // Aquarium-specific ranges (join by common name)
        importAquariumByName();

        // Bổ sung tên tiếng Việt từ wiki_fish_names.csv dựa trên taxonomy (Genus + Species)
        importVietnameseNamesFromWikiCsv();

        // Lưu nội dung 3 file CSV vào bảng fish_dataset_files
        storeDatasetFile(speciesBaseCsvPath, "vn_fish_species_info.csv",
                "Fish species base info (English)");
        storeDatasetFile(speciesInfoCsvPath, "vn_fish_species_info_vi.csv",
                "Fish species info (Vietnamese names and remarks)");
        storeDatasetFile(ecologyBaseCsvPath, "vn_fish_ecology.csv",
            "Fish ecology info (base English rows)");
        storeDatasetFile(ecologyViCsvPath, "vn_fish_ecology_vi.csv",
                "Fish ecology info (Vietnamese conditions description)");
        storeDatasetFile(speciesListCsvPath, "vn_fish_species_list.csv",
            "Fish species list for Vietnam (presence/status)");
        // Lưu thêm file freshwater_aquarium_fish_species.csv để tra cứu lại sau này
        storeDatasetFile(aquariumCsvPath, "freshwater_aquarium_fish_species.csv",
                "Aquarium fish ranges by common name (temp/pH, images, details)");
        storeDatasetFile("classpath:data/wiki_fish_names.csv", "wiki_fish_names.csv",
            "Wiki-derived Vietnamese fish names by scientific taxonomy");
    }

    private String normalizeSci(String s) {
        if (s == null) return null;
        s = s.replace("_", " ");
        s = s.replaceAll("\\s+", " ");
        s = s.replaceAll("[\\[\\]()]", " ");
        s = s.replaceAll("\\s+", " ");
        return s.trim().toLowerCase();
    }

    /**
     * Đọc wiki_fish_names.csv (ScientificName,VietnameseName) và
     * tự điền nameVietnamese cho các loài còn thiếu, dựa trên taxonomy hoặc Genus+Species trong JSON.
     */
    @Transactional
    public void importVietnameseNamesFromWikiCsv() throws IOException {
        Path path;
        try {
            path = resolvePath("classpath:data/wiki_fish_names.csv");
        } catch (IOException e) {
            System.out.println("wiki_fish_names.csv not found on classpath, skip wiki VN names.");
            return;
        }

        Map<String, String> wikiMap = new HashMap<>();

        try (Reader reader = Files.newBufferedReader(path, StandardCharsets.UTF_8);
             CSVReader csvReader = new CSVReaderBuilder(reader).build()) {

            String[] header = csvReader.readNext();
            if (header == null) return;

            int sciIdx = -1, vnIdx = -1;
            for (int i = 0; i < header.length; i++) {
                String h = header[i] != null ? header[i].trim() : "";
                if (h.equalsIgnoreCase("ScientificName")) sciIdx = i;
                if (h.equalsIgnoreCase("VietnameseName")) vnIdx = i;
            }
            if (sciIdx < 0 || vnIdx < 0) {
                System.out.println("wiki_fish_names.csv missing ScientificName/VietnameseName columns.");
                return;
            }

            String[] row;
            while ((row = csvReader.readNext()) != null) {
                if (row.length <= Math.max(sciIdx, vnIdx)) continue;
                String sciRaw = row[sciIdx] != null ? row[sciIdx].trim() : "";
                String vnRaw = row[vnIdx] != null ? row[vnIdx].trim() : "";
                if (sciRaw.isEmpty() || vnRaw.isEmpty()) continue;
                String key = normalizeSci(sciRaw);
                if (!key.isEmpty() && !wikiMap.containsKey(key)) {
                    wikiMap.put(key, vnRaw);
                }
            }
        } catch (CsvValidationException e) {
            throw new IOException("Error reading wiki_fish_names.csv: " + e.getMessage(), e);
        }

        if (wikiMap.isEmpty()) {
            System.out.println("No entries loaded from wiki_fish_names.csv");
            return;
        }

        System.out.println("Loaded " + wikiMap.size() + " wiki VN names. Updating FishSpecies...");

        List<FishSpecies> all = fishSpeciesRepository.findAll();
        int updated = 0;

        for (FishSpecies fish : all) {
            String currentVi = fish.getNameVietnamese();
            if (currentVi != null && !currentVi.isBlank() && !"0".equals(currentVi.trim())) {
                continue; // đã có tên Việt hợp lệ
            }

            String sci = fish.getTaxonomy();
            if (sci == null || sci.isBlank()) {
                sci = extractGenusSpeciesFromJson(fish.getFishbaseSpeciesInfoJson());
            }
            if (sci == null || sci.isBlank()) continue;

            String key = normalizeSci(sci);
            String vn = wikiMap.get(key);
            if (vn != null && !vn.isBlank()) {
                fish.setNameVietnamese(vn);
                updated++;
            }
        }

        fishSpeciesRepository.saveAll(all);
        System.out.println("Updated Vietnamese names from wiki: " + updated);
    }

    private String extractGenusSpeciesFromJson(String json) {
        if (json == null || json.isBlank()) return null;
        try {
            var root = objectMapper.readTree(json);
            String genus = root.path("Genus").asText(null);
            String species = root.path("Species").asText(null);
            if (genus != null && !genus.isBlank() && species != null && !species.isBlank()) {
                return (genus + " " + species).trim();
            }
        } catch (Exception ignored) {
        }
        return null;
    }

    private Double[] parseRange(String rangeStr) {
        if (rangeStr == null) return null;
        String s = rangeStr.toLowerCase(Locale.ROOT)
                .replace("°c", "")
                .replace("oc", "")
                .replace("°", "")
                .replace("ph", "")
                .trim();
        if (s.isEmpty() || "0".equals(s)) return null;

        String[] parts = s.split("\\s*[-–—]\\s*");
        try {
            if (parts.length == 2) {
                double min = Double.parseDouble(parts[0].replace(",", "."));
                double max = Double.parseDouble(parts[1].replace(",", "."));
                return new Double[]{min, max};
            } else if (parts.length == 1) {
                double v = Double.parseDouble(parts[0].replace(",", "."));
                return new Double[]{v, v};
            }
        } catch (NumberFormatException ignored) {
        }
        return null;
    }

    private void computeAutoRanges(FishSpecies fish) {
        if (fish.getTempRange() != null &&
                (fish.getAutoTempMin() == null || fish.getAutoTempMax() == null)) {
            Double[] t = parseRange(fish.getTempRange());
            if (t != null) {
                fish.setAutoTempMin(t[0]);
                fish.setAutoTempMax(t[1]);
            }
        }
        if (fish.getPhRange() != null &&
                (fish.getAutoPhMin() == null || fish.getAutoPhMax() == null)) {
            Double[] p = parseRange(fish.getPhRange());
            if (p != null) {
                fish.setAutoPhMin(p[0]);
                fish.setAutoPhMax(p[1]);
            }
        }
    }

    @Transactional
    public void importSpeciesBaseInfo() throws IOException {
        Path path = resolvePath(speciesBaseCsvPath);

        try (Reader reader = Files.newBufferedReader(path);
             CSVReader csvReader = new CSVReaderBuilder(reader)
                     .withSkipLines(1)
                     .build()) {

            String[] row;
            while ((row = csvReader.readNext()) != null) {
                // vn_fish_species_info.csv header (English):
                // 0: SpecCode, 1: Genus, 4: FBname, 5: PicPreferredName, 66: Comments
                Integer specCode = parseInt(rowSafe(row, 0));
                if (specCode == null) {
                    continue;
                }

                String genus = rowSafe(row, 1);
                String fbname = rowSafe(row, 4);
                String picPreferredName = rowSafe(row, 5);
                String commentsEn = rowSafe(row, 66);

                FishSpecies fish = fishSpeciesRepository
                        .findBySpecCode(specCode)
                        .orElseGet(FishSpecies::new);

                fish.setSpecCode(specCode);

                if (emptyToNull(genus) != null) {
                    fish.setTaxonomy(genus.trim());
                }

                if (emptyToNull(fbname) != null) {
                    fish.setFbName(fbname.trim());
                    fish.setNameEnglish(fbname.trim());
                    fish.setNameKey(normalizeName(fbname));
                }

                if (commentsEn != null && !commentsEn.isBlank()) {
                    String trimmed = commentsEn.trim();
                    fish.setRemarksEn(trimmed);
                    if (fish.getRemarks() == null || fish.getRemarks().isBlank()) {
                        fish.setRemarks(trimmed);
                    }
                }

                if (picPreferredName != null && !picPreferredName.isBlank() &&
                        (fish.getImageUrl() == null || fish.getImageUrl().isBlank())) {
                    String imageUrl = "https://www.fishbase.se/images/species/" + picPreferredName.trim();
                    fish.setPicPreferredName(picPreferredName.trim());
                    fish.setImageUrl(imageUrl);
                }

                if (fish.getIsActive() == null) {
                    fish.setIsActive(true);
                }

                fishSpeciesRepository.save(fish);
            }
        } catch (CsvValidationException e) {
            throw new IOException("Failed to parse base species CSV file: " + e.getMessage(), e);
        }
    }

    @Transactional
    public void importSpeciesInfoVi() throws IOException {
        Path path = resolvePath(speciesInfoCsvPath);

        // Đọc header để build JSON key -> value
        String[] header;
        try (Reader headerReader = Files.newBufferedReader(path);
             CSVReader headerCsv = new CSVReaderBuilder(headerReader).build()) {
            header = headerCsv.readNext();
        } catch (CsvValidationException e) {
            throw new IOException("Failed to read header from Vietnamese species CSV file: " + e.getMessage(), e);
        }

        try (Reader reader = Files.newBufferedReader(path);
             CSVReader csvReader = new CSVReaderBuilder(reader)
                     .withSkipLines(1)
                     .build()) {

            String[] row;
            while ((row = csvReader.readNext()) != null) {
                // Column indexes based on vn_fish_species_info_vi.csv:
                // 0: SpecCode
                // 1: Genus
                // 4: FBname
                // 5: PicPreferredName
                // 66: Comments (EN)
                // 71: NameVietnamese
                // 72: RemarksVietnamese

                Integer specCode = parseInt(rowSafe(row, 0));
                if (specCode == null) {
                    continue;
                }

                String genus = rowSafe(row, 1);
                String fbname = rowSafe(row, 4);
                String picPreferredName = rowSafe(row, 5);
                String commentsEn = rowSafe(row, 66);
                String nameVi = rowSafe(row, 71);
                String remarksVi = rowSafe(row, 72);

                FishSpecies fish = fishSpeciesRepository
                        .findBySpecCode(specCode)
                        .orElseGet(FishSpecies::new);

                fish.setSpecCode(specCode);

                if (emptyToNull(genus) != null) {
                    fish.setTaxonomy(genus.trim());
                }

                if (emptyToNull(fbname) != null) {
                    fish.setFbName(fbname.trim());
                    if (fish.getNameEnglish() == null || fish.getNameEnglish().isBlank()) {
                        fish.setNameEnglish(fbname.trim());
                    }
                    if (fish.getNameKey() == null || fish.getNameKey().isBlank()) {
                        fish.setNameKey(normalizeName(fbname));
                    }
                }

                if (emptyToNull(nameVi) != null) {
                    fish.setNameVietnamese(nameVi.trim());
                }

                if (commentsEn != null && !commentsEn.isBlank()) {
                    String trimmed = commentsEn.trim();
                    fish.setRemarksEn(trimmed);
                }

                if (remarksVi != null && !remarksVi.isBlank()) {
                    String trimmedVi = remarksVi.trim();
                    fish.setRemarksVi(trimmedVi);
                    fish.setRemarks(trimmedVi);
                } else if (fish.getRemarks() == null || fish.getRemarks().isBlank()) {
                    // fallback: dùng tiếng Anh nếu chưa có gì
                    fish.setRemarks(fish.getRemarksEn());
                }

                if (picPreferredName != null && !picPreferredName.isBlank()) {
                    String imageUrl = "https://www.fishbase.se/images/species/" + picPreferredName.trim();
                    fish.setPicPreferredName(picPreferredName.trim());
                    fish.setImageUrl(imageUrl);
                }

                if (fish.getIsActive() == null) {
                    fish.setIsActive(true);
                }

                // Lưu toàn bộ row species_info_vi dưới dạng JSON (key = header)
                try {
                    Map<String, String> jsonMap = buildJsonMap(header, row);
                    fish.setFishbaseSpeciesInfoJson(objectMapper.writeValueAsString(jsonMap));
                } catch (JsonProcessingException e) {
                    // bỏ qua lỗi JSON, không chặn import
                }

                fishSpeciesRepository.save(fish);
            }
        } catch (CsvValidationException e) {
            throw new IOException("Failed to parse Vietnamese species CSV file: " + e.getMessage(), e);
        }
    }

    @Transactional
    public void importEcologyVi() throws IOException {
        Path path = resolvePath(ecologyViCsvPath);

        // Header cho ecology_vi
        String[] header;
        try (Reader headerReader = Files.newBufferedReader(path);
             CSVReader headerCsv = new CSVReaderBuilder(headerReader).build()) {
            header = headerCsv.readNext();
        } catch (CsvValidationException e) {
            throw new IOException("Failed to read header from ecology Vietnamese CSV file: " + e.getMessage(), e);
        }

        try (Reader reader = Files.newBufferedReader(path);
             CSVReader csvReader = new CSVReaderBuilder(reader)
                     .withSkipLines(1)
                     .build()) {

            String[] row;
            while ((row = csvReader.readNext()) != null) {
                // vn_fish_ecology_vi.csv:
                // 1: SpecCode
                // last column: MoTaDieuKienVi (Vietnamese ecology description)
                Integer specCode = parseInt(rowSafe(row, 1));
                if (specCode == null) {
                    continue;
                }

                String moTaDieuKienVi = rowSafe(row, row.length - 1);

                FishSpecies fish = fishSpeciesRepository
                        .findBySpecCode(specCode)
                        .orElseGet(FishSpecies::new);

                fish.setSpecCode(specCode);

                // Append or set remarks with ecology description (Vietnamese)
                if (moTaDieuKienVi != null && !moTaDieuKienVi.isBlank()) {
                    String existing = fish.getRemarksVi();
                    if (existing == null || existing.isBlank()) {
                        fish.setRemarksVi(moTaDieuKienVi.trim());
                    } else if (!existing.contains(moTaDieuKienVi.trim())) {
                        fish.setRemarksVi(existing + "\n\n" + moTaDieuKienVi.trim());
                    }
                    // đồng bộ field remarks dùng để hiển thị mặc định
                    fish.setRemarks(fish.getRemarksVi());
                }

                if (fish.getIsActive() == null) {
                    fish.setIsActive(true);
                }

                // Lưu full row ecology_vi thành JSON
                try {
                    Map<String, String> jsonMap = buildJsonMap(header, row);
                    fish.setFishbaseEcologyJson(objectMapper.writeValueAsString(jsonMap));
                } catch (JsonProcessingException e) {
                    // ignore JSON errors
                }

                fishSpeciesRepository.save(fish);
            }
        } catch (CsvValidationException e) {
            throw new IOException("Failed to parse ecology Vietnamese CSV file: " + e.getMessage(), e);
        }
    }

    @Transactional
    public void importEcologyBase() throws IOException {
        Path path = resolvePath(ecologyBaseCsvPath);

        String[] header;
        try (Reader headerReader = Files.newBufferedReader(path);
             CSVReader headerCsv = new CSVReaderBuilder(headerReader).build()) {
            header = headerCsv.readNext();
        } catch (CsvValidationException e) {
            throw new IOException("Failed to read header from ecology base CSV file: " + e.getMessage(), e);
        }

        int addRemsIndex = -1;
        if (header != null) {
            for (int i = 0; i < header.length; i++) {
                String h = header[i] != null ? header[i].trim() : "";
                if ("AddRems".equalsIgnoreCase(h)) {
                    addRemsIndex = i;
                    break;
                }
            }
        }

        try (Reader reader = Files.newBufferedReader(path);
             CSVReader csvReader = new CSVReaderBuilder(reader)
                     .withSkipLines(1)
                     .build()) {

            String[] row;
            while ((row = csvReader.readNext()) != null) {
                Integer specCode = parseInt(rowSafe(row, 1)); // SpecCode
                if (specCode == null) {
                    continue;
                }

                String addRems = addRemsIndex >= 0 ? rowSafe(row, addRemsIndex) : null;

                FishSpecies fish = fishSpeciesRepository
                        .findBySpecCode(specCode)
                        .orElseGet(FishSpecies::new);

                fish.setSpecCode(specCode);

                if (addRems != null && !addRems.isBlank()) {
                    String enText = addRems.trim();
                    if (fish.getRemarksEn() == null || fish.getRemarksEn().isBlank()) {
                        fish.setRemarksEn(enText);
                    }
                    if ((fish.getRemarks() == null || fish.getRemarks().isBlank())
                            && (fish.getRemarksVi() == null || fish.getRemarksVi().isBlank())) {
                        fish.setRemarks(enText);
                    }
                }

                if (fish.getIsActive() == null) {
                    fish.setIsActive(true);
                }

                fishSpeciesRepository.save(fish);
            }
        } catch (CsvValidationException e) {
            throw new IOException("Failed to parse ecology base CSV file: " + e.getMessage(), e);
        }
    }

    private void storeDatasetFile(String configuredPath,
                                  String logicalFileName,
                                  String description) throws IOException {
        Path path = resolvePath(configuredPath);
        String content = Files.readString(path, StandardCharsets.UTF_8);

        FishDatasetFile file = fishDatasetFileRepository
                .findByFileName(logicalFileName)
                .orElseGet(FishDatasetFile::new);

        file.setFileName(logicalFileName);
        file.setDescription(description);
        file.setContent(content);

        fishDatasetFileRepository.save(file);
    }

    private Map<String, String> buildJsonMap(String[] header, String[] row) {
        Map<String, String> map = new LinkedHashMap<>();
        if (header == null) {
            return map;
        }
        int len = Math.min(header.length, row.length);
        for (int i = 0; i < len; i++) {
            String key = header[i];
            if (key == null || key.isBlank()) continue;
            map.put(key.replace("\"", "").trim(), row[i]);
        }
        return map;
    }

    private String normalizeName(String s) {
        if (s == null) return null;
        String normalized = s.trim().toLowerCase();
        while (normalized.contains("  ")) {
            normalized = normalized.replace("  ", " ");
        }
        return normalized;
    }

    private Double parseDouble(String s) {
        try {
            if (s == null) return null;
            String trimmed = s.trim();
            if (trimmed.isEmpty()) return null;
            return Double.parseDouble(trimmed);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /**
     * Import aquarium-specific ranges (temprange, phRange, detailsUrl, imageURL) by joining on common name.
     * freshwater_aquarium_fish_species.csv header:
     * name,taxonomy,imageURL,remarks,temprange,phRange,detailsUrl
     */
    @Transactional
    public void importAquariumByName() throws IOException {
        Path path = resolvePath(aquariumCsvPath);

        try (Reader reader = Files.newBufferedReader(path);
             CSVReader csv = new CSVReaderBuilder(reader).withSkipLines(1).build()) {

            String[] row;
            while ((row = csv.readNext()) != null) {
                String rawName   = rowSafe(row, 0);      // name (common name, English)
                String taxonomy  = rowSafe(row, 1);      // taxonomy (scientific name)
                String imageUrl  = rowSafe(row, 2);      // imageURL
                String tempRange = rowSafe(row, 4);      // temprange (string)
                String phRange   = rowSafe(row, 5);      // phRange (string, possibly multiline)
                String detailsUrl= rowSafe(row, 6);      // detailsUrl

                if (rawName == null || rawName.isBlank()) {
                    continue;
                }

                String key = normalizeName(rawName);
                if (key == null || key.isBlank()) continue;

                FishSpecies fish = fishSpeciesRepository.findFirstByNameKey(key).orElse(null);
                if (fish == null) {
                    // Không tìm thấy loài khớp tên trong FishBase → tạo mới bản ghi FishSpecies tối thiểu
                    fish = new FishSpecies();
                    fish.setNameEnglish(rawName.trim());
                    fish.setNameKey(key);
                    if (taxonomy != null && !taxonomy.isBlank()) {
                        fish.setTaxonomy(taxonomy.trim());
                    }
                    fish.setIsActive(true);
                }

                // Cập nhật thông tin hiển thị nếu trống
                if ((fish.getImageUrl() == null || fish.getImageUrl().isBlank()) &&
                        imageUrl != null && !imageUrl.isBlank()) {
                    fish.setImageUrl(imageUrl.trim());
                }

                if (tempRange != null && !tempRange.isBlank() &&
                        (fish.getTempRange() == null || fish.getTempRange().isBlank())) {
                    fish.setTempRange(tempRange.trim());
                }

                if (phRange != null && !phRange.isBlank() &&
                        (fish.getPhRange() == null || fish.getPhRange().isBlank())) {
                    fish.setPhRange(phRange.trim());
                }

                // Sau khi cập nhật temp_range / ph_range, tính autoTemp*/autoPh*
                computeAutoRanges(fish);

                if (detailsUrl != null && !detailsUrl.isBlank() &&
                        (fish.getDetailsUrl() == null || fish.getDetailsUrl().isBlank())) {
                    fish.setDetailsUrl(detailsUrl.trim());
                }

                fishSpeciesRepository.save(fish);
            }

        } catch (CsvValidationException e) {
            throw new IOException("Failed to parse aquarium CSV file: " + e.getMessage(), e);
        }
    }

    /**
     * Import Vietnam distribution/status info from vn_fish_species_list.csv, joined by SpecCode.
     * Header:
     * "autoctr","Stockcode","C_Code","SpecCode","CountryRefNo","AlsoRef","Status",
     * "CurrentPresence","Freshwater","Brackish","Saltwater","Land","Comments",
     * "Abundance","RefAbundance","Importance",...
     */
    @Transactional
    public void importSpeciesListVietNam() throws IOException {
        Path path = resolvePath(speciesListCsvPath);

        try (Reader reader = Files.newBufferedReader(path);
             CSVReader csv = new CSVReaderBuilder(reader).withSkipLines(1).build()) {

            String[] row;
            while ((row = csv.readNext()) != null) {
                Integer specCode = parseInt(rowSafe(row, 3)); // SpecCode
                if (specCode == null) continue;

                String status          = rowSafe(row, 6);
                String currentPresence = rowSafe(row, 7);
                String freshwaterFlag  = rowSafe(row, 8);
                String brackishFlag    = rowSafe(row, 9);
                String saltwaterFlag   = rowSafe(row, 10);
                String comments        = rowSafe(row, 12);
                String abundance       = rowSafe(row, 13);
                String importance      = rowSafe(row, 15);

                FishSpecies fish = fishSpeciesRepository
                        .findBySpecCode(specCode)
                        .orElseGet(FishSpecies::new);

                fish.setSpecCode(specCode);

                if (status != null && !status.isBlank()) {
                    fish.setVnStatus(status.trim());
                }
                if (currentPresence != null && !currentPresence.isBlank()) {
                    fish.setVnCurrentPresence(currentPresence.trim());
                }

                fish.setVnFreshwater("1".equals(freshwaterFlag));
                fish.setVnBrackish("1".equals(brackishFlag));
                fish.setVnSaltwater("1".equals(saltwaterFlag));

                if (comments != null && !comments.isBlank()) {
                    fish.setVnDistributionComments(comments.trim());
                }
                if (abundance != null && !abundance.isBlank()) {
                    fish.setVnAbundance(abundance.trim());
                }
                if (importance != null && !importance.isBlank()) {
                    fish.setVnImportance(importance.trim());
                }

                if (fish.getIsActive() == null) {
                    fish.setIsActive(true);
                }

                fishSpeciesRepository.save(fish);
            }

        } catch (CsvValidationException e) {
            throw new IOException("Failed to parse vn_fish_species_list.csv: " + e.getMessage(), e);
        }
    }

    private String rowSafe(String[] row, int index) {
        return index >= 0 && index < row.length ? row[index] : null;
    }

    private Integer parseInt(String s) {
        try {
            if (s == null) return null;
            s = s.trim();
            if (s.isEmpty()) return null;
            return Integer.parseInt(s);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private String emptyToNull(String s) {
        if (s == null) return null;
        String trimmed = s.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private Path resolvePath(String value) throws IOException {
        if (value.startsWith("classpath:")) {
            String cp = value.substring("classpath:".length());
            URL url = getClass().getClassLoader().getResource(cp);
            if (url == null) {
                throw new IOException("Classpath resource not found: " + cp);
            }
            try {
                // Use URI to avoid leading "/" issues on Windows like "/E:/..."
                return Paths.get(url.toURI());
            } catch (Exception e) {
                throw new IOException("Failed to resolve classpath resource to path: " + cp, e);
            }
        }
        return Paths.get(value);
    }
}

