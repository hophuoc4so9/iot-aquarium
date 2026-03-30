package backend_iot_aquarium.backend_iot_aquarium.model;

import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(name = "fish_disease_diagnoses")
public class FishDiseaseDiagnosis {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "username", nullable = false)
    private String username;

    @Column(name = "pond_id")
    private Long pondId;

    @Column(name = "pond_name")
    private String pondName;

    @Column(name = "image_name")
    private String imageName;

    @Column(name = "label", nullable = false)
    private String label;

    @Column(name = "score")
    private Double score;

    @Column(name = "diagnosed_at", nullable = false)
    private Instant diagnosedAt;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public Long getPondId() {
        return pondId;
    }

    public void setPondId(Long pondId) {
        this.pondId = pondId;
    }

    public String getPondName() {
        return pondName;
    }

    public void setPondName(String pondName) {
        this.pondName = pondName;
    }

    public String getImageName() {
        return imageName;
    }

    public void setImageName(String imageName) {
        this.imageName = imageName;
    }

    public String getLabel() {
        return label;
    }

    public void setLabel(String label) {
        this.label = label;
    }

    public Double getScore() {
        return score;
    }

    public void setScore(Double score) {
        this.score = score;
    }

    public Instant getDiagnosedAt() {
        return diagnosedAt;
    }

    public void setDiagnosedAt(Instant diagnosedAt) {
        this.diagnosedAt = diagnosedAt;
    }
}
