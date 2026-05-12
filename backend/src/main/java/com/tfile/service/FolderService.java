package com.tfile.service;

import com.tfile.api.dto.FolderDtos.FolderCreateRequest;
import com.tfile.api.dto.FolderDtos.FolderResponse;
import com.tfile.api.dto.FolderDtos.FolderUpdateRequest;
import com.tfile.domain.Folder;
import com.tfile.repo.FolderRepository;
import com.tfile.repo.ItemRepository;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
@RequiredArgsConstructor
public class FolderService {

  private final FolderRepository folderRepository;
  private final ItemRepository itemRepository;

  @Transactional
  public FolderResponse create(FolderCreateRequest req) {
    Folder parent = resolveParent(req.parentId());
    Folder f = new Folder(req.name().trim(), parent);
    folderRepository.save(f);
    return toResponse(f);
  }

  @Transactional(readOnly = true)
  public FolderResponse get(UUID id) {
    return toResponse(folderRepository.findById(id).orElseThrow(FolderService::notFound));
  }

  @Transactional(readOnly = true)
  public List<FolderResponse> list(UUID parentId) {
    List<Folder> list =
        parentId == null
            ? folderRepository.findByParentIsNull()
            : folderRepository.findByParent_Id(parentId);
    return list.stream().map(this::toResponse).toList();
  }

  @Transactional
  public FolderResponse update(UUID id, FolderUpdateRequest req) {
    Folder f = folderRepository.findById(id).orElseThrow(FolderService::notFound);
    f.setName(req.name().trim());
    f.setParent(resolveParent(req.parentId()));
    if (wouldCreateCycle(f)) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid parent: cycle detected");
    }
    return toResponse(f);
  }

  @Transactional
  public void delete(UUID id) {
    Folder f = folderRepository.findById(id).orElseThrow(FolderService::notFound);
    if (folderRepository.existsByParent_Id(id)) {
      throw new ResponseStatusException(HttpStatus.CONFLICT, "Folder has subfolders");
    }
    if (itemRepository.existsByFolder_Id(id)) {
      throw new ResponseStatusException(HttpStatus.CONFLICT, "Folder contains items");
    }
    folderRepository.delete(f);
  }

  private Folder resolveParent(UUID parentId) {
    if (parentId == null) {
      return null;
    }
    return folderRepository.findById(parentId).orElseThrow(FolderService::notFound);
  }

  private boolean wouldCreateCycle(Folder folder) {
    Folder p = folder.getParent();
    UUID movingId = folder.getId();
    int guard = 0;
    while (p != null && guard++ < 10_000) {
      if (p.getId().equals(movingId)) {
        return true;
      }
      p = p.getParent();
    }
    return false;
  }

  private FolderResponse toResponse(Folder f) {
    return new FolderResponse(
        f.getId(),
        f.getName(),
        f.getParent() == null ? null : f.getParent().getId(),
        f.getCreatedAt().toString());
  }

  private static ResponseStatusException notFound() {
    return new ResponseStatusException(HttpStatus.NOT_FOUND, "Folder not found");
  }
}
