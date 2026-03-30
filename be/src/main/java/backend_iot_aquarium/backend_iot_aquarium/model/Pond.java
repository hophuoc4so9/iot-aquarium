package backend_iot_aquarium.backend_iot_aquarium.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "ponds")
public class Pond {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "name", nullable = false)
    private String name;

    @Column(name = "area")
    private String area;

    @Column(name = "fish_type")
    private String fishType;

    @Column(name = "stocking_date")
    private String stockingDate;

    @Column(name = "density")
    private String density;

    @Column(name = "note")
    private String note;

    // Username của chủ ao (user app-user). Có thể null nếu ao chưa được gán.
    @Column(name = "owner_username")
    private String ownerUsername;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getArea() {
        return area;
    }

    public void setArea(String area) {
        this.area = area;
    }

    public String getFishType() {
        return fishType;
    }

    public void setFishType(String fishType) {
        this.fishType = fishType;
    }

    public String getStockingDate() {
        return stockingDate;
    }

    public void setStockingDate(String stockingDate) {
        this.stockingDate = stockingDate;
    }

    public String getDensity() {
        return density;
    }

    public void setDensity(String density) {
        this.density = density;
    }

    public String getNote() {
        return note;
    }

    public void setNote(String note) {
        this.note = note;
    }

    public String getOwnerUsername() {
        return ownerUsername;
    }

    public void setOwnerUsername(String ownerUsername) {
        this.ownerUsername = ownerUsername;
    }
}

