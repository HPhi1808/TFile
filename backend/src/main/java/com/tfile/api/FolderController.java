package com.tfile.api;

import com.tfile.api.dto.FolderDtos.FolderCreateRequest;
import com.tfile.api.dto.FolderDtos.FolderResponse;
import com.tfile.api.dto.FolderDtos.FolderUpdateRequest;
import com.tfile.service.FolderService;
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
@RequestMapping("/api/folders")
@RequiredArgsConstructor
public class FolderController {

  private final FolderService folderService;

  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  public FolderResponse create(@Valid @RequestBody FolderCreateRequest body) {
    return folderService.create(body);
  }

  @GetMapping("/{id}")
  public FolderResponse get(@PathVariable UUID id) {
    return folderService.get(id);
  }

  /** Không gửi {@code parentId} = các folder gốc; có {@code parentId} = con trực tiếp của folder đó. */
  @GetMapping
  public List<FolderResponse> list(@RequestParam(required = false) UUID parentId) {
    return folderService.list(parentId);
  }

  @PutMapping("/{id}")
  public FolderResponse update(@PathVariable UUID id, @Valid @RequestBody FolderUpdateRequest body) {
    return folderService.update(id, body);
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  public void delete(@PathVariable UUID id) {
    folderService.delete(id);
  }
}
