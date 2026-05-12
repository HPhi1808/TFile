package com.tfile.repo;

import com.tfile.domain.Item;
import jakarta.persistence.criteria.JoinType;
import jakarta.persistence.criteria.Predicate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.domain.Specification;

public final class ItemSpecifications {

  private ItemSpecifications() {}

  /**
   * @param trashed null = chỉ item chưa xoá mềm; true = thùng rác; false = chỉ active
   * @param favorite null = bỏ qua; true/false = lọc theo cờ yêu thích
   * @param folderId null = mọi folder; có giá trị = theo folder đó (kể cả item chưa gán folder cần sentinel — ở đây chỉ lọc khi UUID được truyền)
   */
  public static Specification<Item> filtered(Boolean trashed, Boolean favorite, UUID folderId) {
    return (root, query, cb) -> {
      List<Predicate> ps = new ArrayList<>();

      if (Boolean.TRUE.equals(trashed)) {
        ps.add(cb.isTrue(root.get("trashed")));
      } else {
        ps.add(cb.isFalse(root.get("trashed")));
      }

      if (favorite != null) {
        ps.add(cb.equal(root.get("favorite"), favorite));
      }

      if (folderId != null) {
        var folderJoin = root.join("folder", JoinType.INNER);
        ps.add(cb.equal(folderJoin.get("id"), folderId));
      }

      return cb.and(ps.toArray(Predicate[]::new));
    };
  }
}
