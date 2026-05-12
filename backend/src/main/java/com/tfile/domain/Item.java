package com.tfile.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "items")
@Getter
@Setter
@NoArgsConstructor
public class Item {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private UUID id;

  @Column(nullable = false)
  private String name;

  @Column(nullable = false)
  private Long size;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private ItemType type;

  @Column(name = "telegram_file_id", nullable = false)
  private String telegramFileId;

  @Column(name = "telegram_thumb_id", nullable = false)
  private String telegramThumbId;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "folder_id")
  private Folder folder;

  @Column(name = "is_favorite", nullable = false)
  private boolean favorite;

  @Column(name = "is_trashed", nullable = false)
  private boolean trashed;

  @Column(name = "trashed_at")
  private Instant trashedAt;

  public Item(
      String name,
      long size,
      ItemType type,
      String telegramFileId,
      String telegramThumbId,
      Folder folder,
      boolean favorite) {
    this.name = name;
    this.size = size;
    this.type = type;
    this.telegramFileId = telegramFileId;
    this.telegramThumbId = telegramThumbId;
    this.folder = folder;
    this.favorite = favorite;
    this.trashed = false;
  }
}
