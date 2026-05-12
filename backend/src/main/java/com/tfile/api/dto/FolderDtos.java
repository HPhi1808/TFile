package com.tfile.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.UUID;

public final class FolderDtos {

  private FolderDtos() {}

  public record FolderCreateRequest(
      @NotBlank @Size(max = 512) String name, UUID parentId) {}

  public record FolderUpdateRequest(
      @NotBlank @Size(max = 512) String name, UUID parentId) {}

  public record FolderResponse(UUID id, String name, UUID parentId, String createdAt) {}
}
