package com.tfile.service;

import com.tfile.api.dto.ItemDtos.ItemCreateRequest;
import com.tfile.api.dto.ItemDtos.ItemResponse;
import com.tfile.api.dto.ItemDtos.ItemUpdateRequest;
import com.tfile.domain.Folder;
import com.tfile.domain.Item;
import com.tfile.repo.FolderRepository;
import com.tfile.repo.ItemRepository;
import com.tfile.repo.ItemSpecifications;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
@RequiredArgsConstructor
public class ItemService {

  private final ItemRepository itemRepository;
  private final FolderRepository folderRepository;

  @Transactional
  public ItemResponse create(ItemCreateRequest req) {
    Folder folder = resolveFolder(req.folderId());
    Item item =
        new Item(
            req.name().trim(),
            req.size(),
            req.type(),
            req.telegramFileId(),
            req.telegramThumbId(),
            folder,
            req.favorite());
    itemRepository.save(item);
    return toResponse(item);
  }

  @Transactional(readOnly = true)
  public ItemResponse get(UUID id) {
    return toResponse(itemRepository.findById(id).orElseThrow(ItemService::notFound));
  }

  @Transactional(readOnly = true)
  public List<ItemResponse> list(Boolean trashed, Boolean favorite, UUID folderId) {
    Boolean trashParam = trashed;
    return itemRepository
        .findAll(ItemSpecifications.filtered(trashParam, favorite, folderId))
        .stream()
        .map(this::toResponse)
        .toList();
  }

  @Transactional
  public ItemResponse update(UUID id, ItemUpdateRequest req) {
    Item item = itemRepository.findById(id).orElseThrow(ItemService::notFound);
    item.setName(req.name().trim());
    item.setSize(req.size());
    item.setType(req.type());
    item.setTelegramFileId(req.telegramFileId());
    item.setTelegramThumbId(req.telegramThumbId());
    item.setFolder(resolveFolder(req.folderId()));
    item.setFavorite(req.favorite());
    if (req.trashed()) {
      if (!item.isTrashed()) {
        item.setTrashed(true);
        item.setTrashedAt(Instant.now());
      }
    } else {
      item.setTrashed(false);
      item.setTrashedAt(null);
    }
    return toResponse(item);
  }

  /** Soft delete: đưa vào thùng rác. */
  @Transactional
  public void softDelete(UUID id) {
    Item item = itemRepository.findById(id).orElseThrow(ItemService::notFound);
    item.setTrashed(true);
    item.setTrashedAt(Instant.now());
  }

  private Folder resolveFolder(UUID folderId) {
    if (folderId == null) {
      return null;
    }
    return folderRepository.findById(folderId).orElseThrow(ItemService::notFoundFolder);
  }

  private ItemResponse toResponse(Item item) {
    return new ItemResponse(
        item.getId(),
        item.getName(),
        item.getSize(),
        item.getType(),
        item.getTelegramFileId(),
        item.getTelegramThumbId(),
        item.getFolder() == null ? null : item.getFolder().getId(),
        item.isFavorite(),
        item.isTrashed(),
        item.getTrashedAt() == null ? null : item.getTrashedAt().toString());
  }

  private static ResponseStatusException notFound() {
    return new ResponseStatusException(HttpStatus.NOT_FOUND, "Item not found");
  }

  private static ResponseStatusException notFoundFolder() {
    return new ResponseStatusException(HttpStatus.NOT_FOUND, "Folder not found");
  }
}
