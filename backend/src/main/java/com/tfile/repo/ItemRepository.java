package com.tfile.repo;

import com.tfile.domain.Item;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface ItemRepository extends JpaRepository<Item, UUID>, JpaSpecificationExecutor<Item> {

  boolean existsByFolder_Id(UUID folderId);

  List<Item> findByTrashedIsTrueAndTrashedAtBefore(Instant cutoff);
}
