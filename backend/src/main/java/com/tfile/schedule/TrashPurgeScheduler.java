package com.tfile.schedule;

import com.tfile.domain.Item;
import com.tfile.repo.ItemRepository;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Mỗi ngày một lần: item đã xoá mềm quá 30 ngày — log ID rồi xoá record (Telegram API gọi sau).
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class TrashPurgeScheduler {

  private final ItemRepository itemRepository;

  @Scheduled(cron = "0 0 2 * * *")
  @Transactional
  public void purgeExpiredTrash() {
    Instant cutoff = Instant.now().minus(30, ChronoUnit.DAYS);
    List<Item> expired = itemRepository.findByTrashedIsTrueAndTrashedAtBefore(cutoff);
    if (expired.isEmpty()) {
      log.info("Trash purge: no items older than 30 days");
      return;
    }
    for (Item item : expired) {
      log.info("Trash purge: permanently deleting item id={} (Telegram cleanup deferred)", item.getId());
    }
    itemRepository.deleteAllInBatch(expired);
    log.info("Trash purge: removed {} row(s)", expired.size());
  }
}
