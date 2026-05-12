-- ============================================================
--  clp_framework — Initial DB-Schema (Phase 0)
--  © Contentlos / CLP
--
--  Wird beim Resource-Start von server/db.lua:applySchema() ausgeführt,
--  sofern Config.AutoApplySchema = true (Default).
--  Idempotent — Statements können beliebig oft ausgeführt werden.
--
--  Schema-Konventionen:
--    - Alle Tabellen MIT Prefix `clp_`
--    - Engine InnoDB, Charset utf8mb4
--    - Timestamps in UTC, Spaltennamen snake_case
--    - JSON-Spalten via TEXT (kompatibler als JSON-Type für ältere MariaDB)
-- ============================================================

-- ============================================================
--  USERS  — pro physischem Spieler (per primary identifier)
-- ============================================================
CREATE TABLE IF NOT EXISTS `clp_users` (
    `identifier`    VARCHAR(64) NOT NULL,
    `license`       VARCHAR(64) DEFAULT NULL,
    `license2`      VARCHAR(64) DEFAULT NULL,
    `steam`         VARCHAR(32) DEFAULT NULL,
    `discord`       VARCHAR(32) DEFAULT NULL,
    `fivem`         VARCHAR(32) DEFAULT NULL,
    `ip`            VARCHAR(45) DEFAULT NULL,
    `last_name`     VARCHAR(64) DEFAULT NULL,  -- letzter Player-Name (NICHT RP-Name)
    `group`         VARCHAR(32) NOT NULL DEFAULT 'user',
    `first_seen`    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_seen`     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `banned`        TINYINT(1)  NOT NULL DEFAULT 0,
    `ban_reason`    TEXT        DEFAULT NULL,
    `ban_until`     DATETIME    DEFAULT NULL,
    PRIMARY KEY (`identifier`),
    KEY `idx_users_license` (`license`),
    KEY `idx_users_steam` (`steam`),
    KEY `idx_users_discord` (`discord`),
    KEY `idx_users_group` (`group`),
    KEY `idx_users_banned` (`banned`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
--  CHARACTERS  — n pro user
-- ============================================================
CREATE TABLE IF NOT EXISTS `clp_characters` (
    `citizenid`     VARCHAR(16) NOT NULL,
    `user_id`       VARCHAR(64) NOT NULL,
    `slot`          TINYINT     NOT NULL DEFAULT 1,

    `firstname`     VARCHAR(32) NOT NULL,
    `lastname`      VARCHAR(32) NOT NULL,
    `birthdate`     DATE        DEFAULT NULL,
    `gender`        ENUM('m','f','d') NOT NULL DEFAULT 'm',
    `nationality`   VARCHAR(32) DEFAULT NULL,
    `phone`         VARCHAR(16) DEFAULT NULL,

    `job`           VARCHAR(32) NOT NULL DEFAULT 'unemployed',
    `job_grade`     TINYINT     NOT NULL DEFAULT 0,
    `on_duty`       TINYINT(1)  NOT NULL DEFAULT 0,
    `gang`          VARCHAR(32) DEFAULT NULL,
    `gang_grade`    TINYINT     DEFAULT NULL,

    `cash`          BIGINT      NOT NULL DEFAULT 0,
    `bank`          BIGINT      NOT NULL DEFAULT 0,
    `black_money`   BIGINT      NOT NULL DEFAULT 0,

    `metadata`      LONGTEXT    DEFAULT NULL,   -- JSON: hunger, durst, stress, skin, ...
    `position`      TEXT        DEFAULT NULL,   -- JSON: {x,y,z,h}

    `playtime_seconds` BIGINT   NOT NULL DEFAULT 0,
    `created_at`    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `last_seen`     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `deleted_at`    DATETIME    DEFAULT NULL,

    PRIMARY KEY (`citizenid`),
    KEY `idx_chars_user` (`user_id`),
    KEY `idx_chars_user_slot` (`user_id`, `slot`),
    KEY `idx_chars_job` (`job`, `job_grade`),
    KEY `idx_chars_name` (`firstname`, `lastname`),
    KEY `idx_chars_deleted` (`deleted_at`),
    CONSTRAINT `fk_chars_user`
        FOREIGN KEY (`user_id`) REFERENCES `clp_users`(`identifier`)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
--  CHARACTER LOG  — Audit-Log (Login, Job-Wechsel, Geld, ...)
-- ============================================================
CREATE TABLE IF NOT EXISTS `clp_character_log` (
    `id`            BIGINT      NOT NULL AUTO_INCREMENT,
    `citizenid`     VARCHAR(16) NOT NULL,
    `type`          VARCHAR(32) NOT NULL,
    `payload`       LONGTEXT    DEFAULT NULL,
    `actor`         VARCHAR(64) DEFAULT NULL,  -- 'system' | 'admin:<citizenid>' | 'self'
    `created_at`    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_log_citizen_time` (`citizenid`, `created_at`),
    KEY `idx_log_type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
--  JOBS / GRADES   — wird in Phase 2 mit Default-Daten geseedet
-- ============================================================
CREATE TABLE IF NOT EXISTS `clp_jobs` (
    `name`          VARCHAR(32) NOT NULL,
    `label`         VARCHAR(64) NOT NULL,
    `whitelisted`   TINYINT(1)  NOT NULL DEFAULT 0,
    `category`      VARCHAR(32) DEFAULT NULL,  -- 'staat' | 'company' | 'gang' | 'civilian'
    `metadata`      LONGTEXT    DEFAULT NULL,
    `created_at`    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `clp_job_grades` (
    `job`           VARCHAR(32) NOT NULL,
    `grade`         TINYINT     NOT NULL,
    `label`         VARCHAR(64) NOT NULL,
    `salary`        INT         NOT NULL DEFAULT 0,
    `permissions`   LONGTEXT    DEFAULT NULL,
    PRIMARY KEY (`job`, `grade`),
    CONSTRAINT `fk_grades_job`
        FOREIGN KEY (`job`) REFERENCES `clp_jobs`(`name`)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
--  INVENTORY  (Phase 5 — Spalten schon da, Logik kommt später)
-- ============================================================
CREATE TABLE IF NOT EXISTS `clp_character_inventory` (
    `id`            BIGINT      NOT NULL AUTO_INCREMENT,
    `citizenid`     VARCHAR(16) NOT NULL,
    `slot`          SMALLINT    NOT NULL,
    `item`          VARCHAR(64) NOT NULL,
    `count`         INT         NOT NULL DEFAULT 1,
    `weight`        DECIMAL(10,3) DEFAULT 0,
    `metadata`      LONGTEXT    DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_inv_slot` (`citizenid`, `slot`),
    KEY `idx_inv_item` (`item`),
    CONSTRAINT `fk_inv_char`
        FOREIGN KEY (`citizenid`) REFERENCES `clp_characters`(`citizenid`)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
--  VEHICLES  (Phase 6)
-- ============================================================
CREATE TABLE IF NOT EXISTS `clp_character_vehicles` (
    `plate`         VARCHAR(8)  NOT NULL,
    `citizenid`     VARCHAR(16) NOT NULL,
    `model`         VARCHAR(48) NOT NULL,
    `garage`        VARCHAR(32) DEFAULT NULL,
    `state`         TINYINT     NOT NULL DEFAULT 1,  -- 0=out, 1=garage, 2=impound
    `mods`          LONGTEXT    DEFAULT NULL,
    `fuel`          DECIMAL(5,2) DEFAULT 100.00,
    `engine_health` DECIMAL(7,2) DEFAULT 1000.00,
    `body_health`   DECIMAL(7,2) DEFAULT 1000.00,
    `created_at`    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`plate`),
    KEY `idx_veh_owner` (`citizenid`),
    KEY `idx_veh_garage` (`garage`, `state`),
    CONSTRAINT `fk_veh_owner`
        FOREIGN KEY (`citizenid`) REFERENCES `clp_characters`(`citizenid`)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
--  DOORS  (Phase 7)
-- ============================================================
CREATE TABLE IF NOT EXISTS `clp_doors` (
    `id`            VARCHAR(64) NOT NULL,
    `name`          VARCHAR(64) NOT NULL,
    `coords`        TEXT        DEFAULT NULL,  -- JSON {x,y,z}
    `model`         VARCHAR(48) DEFAULT NULL,
    `heading`       DECIMAL(6,2) DEFAULT NULL,
    `locked`        TINYINT(1)  NOT NULL DEFAULT 1,
    `permissions`   LONGTEXT    DEFAULT NULL,  -- JSON
    `created_at`    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
--  KEY-VALUE-STORE   — für ad-hoc Framework-Settings (Migrations-Version etc.)
-- ============================================================
CREATE TABLE IF NOT EXISTS `clp_kv` (
    `k`             VARCHAR(64) NOT NULL,
    `v`             LONGTEXT    DEFAULT NULL,
    `updated_at`    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`k`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
