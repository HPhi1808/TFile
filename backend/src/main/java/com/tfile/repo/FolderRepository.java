package com.tfile.repo;

import com.tfile.domain.Folder;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface FolderRepository extends JpaRepository<Folder, UUID> {

  List<Folder> findByParent_Id(UUID parentId);

  List<Folder> findByParentIsNull();

  boolean existsByParent_Id(UUID parentId);

  long countByParent_Id(UUID parentId);
}
