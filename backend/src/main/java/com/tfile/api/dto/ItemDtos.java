package com.tfile.api.dto;

import com.tfile.domain.ItemType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.util.UUID;

public final class ItemDtos {

  private ItemDtos() {}

  public record ItemCreateRequest(
      @NotBlank @Size(max = 512) String name,
      @NotNull @PositiveOrZero Long size,
      @NotNull ItemType type,
      @NotBlank @Size(max = 512) String telegramFileId,
      @NotBlank @Size(max = 512) String telegramThumbId,
      UUID folderId,
      boolean favorite) {}

  public record ItemUpdateRequest(
      @NotBlank @Size(max = 512) String name,
      @NotNull @PositiveOrZero Long size,
      @NotNull ItemType type,
      @NotBlank @Size(max = 512) String telegramFileId,
      @NotBlank @Size(max = 512) String telegramThumbId,
      UUID folderId,
      boolean favorite,
      boolean trashed) {}

  public record ItemResponse(
      UUID id,
      String name,
      long size,
      ItemType type,
      String telegramFileId,
      String telegramThumbId,
      UUID folderId,
      boolean favorite,
      boolean trashed,
      String trashedAt) {}
}
