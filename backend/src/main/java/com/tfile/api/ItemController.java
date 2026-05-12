package com.tfile.api;

import com.tfile.api.dto.ItemDtos.ItemCreateRequest;
import com.tfile.api.dto.ItemDtos.ItemResponse;
import com.tfile.api.dto.ItemDtos.ItemUpdateRequest;
import com.tfile.service.ItemService;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/items")
@RequiredArgsConstructor
public class ItemController {

  private final ItemService itemService;

  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  public ItemResponse create(@Valid @RequestBody ItemCreateRequest body) {
    return itemService.create(body);
  }

  @GetMapping("/{id}")
  public ItemResponse get(@PathVariable UUID id) {
    return itemService.get(id);
  }

  /**
   * @param folderId lọc theo folder
   * @param trashed true = thùng rác; false/null = chỉ item chưa xoá mềm
   * @param favorite null = mọi trạng thái yêu thích; true/false = lọc theo cờ
   */
  @GetMapping
  public List<ItemResponse> list(
      @RequestParam(required = false) UUID folderId,
      @RequestParam(required = false) Boolean trashed,
      @RequestParam(required = false) Boolean favorite) {
    return itemService.list(trashed, favorite, folderId);
  }

  @PutMapping("/{id}")
  public ItemResponse update(@PathVariable UUID id, @Valid @RequestBody ItemUpdateRequest body) {
    return itemService.update(id, body);
  }

  /** Soft delete: {@code is_trashed=true}, {@code trashed_at=now}. */
  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  public void delete(@PathVariable UUID id) {
    itemService.softDelete(id);
  }
}
