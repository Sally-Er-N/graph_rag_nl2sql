DROP DATABASE IF EXISTS `handicraft_store`;
CREATE DATABASE `handicraft_store` 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE `handicraft_store`;

DROP TABLE IF EXISTS `artist`;
CREATE TABLE `artist` (
    `artist_id` INT NOT NULL AUTO_INCREMENT COMMENT '艺术家ID，主键',
    `name` VARCHAR(100) NOT NULL COMMENT '艺术家姓名',
    `country_code` CHAR(2) DEFAULT NULL COMMENT '国家代码，ISO 3166-1 alpha-2格式，如CN、US、UK',
    `bio` TEXT COMMENT '艺术家简介（英文）',
    `profile_image_url` VARCHAR(500) DEFAULT NULL COMMENT '头像图片URL',
    `website` VARCHAR(255) DEFAULT NULL COMMENT '个人网站',
    `instagram_handle` VARCHAR(50) DEFAULT NULL COMMENT 'Instagram账号，不含@符号',
    `featured` BOOLEAN DEFAULT FALSE COMMENT '是否为精选艺术家（首页推荐）',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`artist_id`),
    INDEX `idx_country` (`country_code`),
    INDEX `idx_featured` (`featured`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='艺术家信息表，存储手工艺品的创作者信息';

DROP TABLE IF EXISTS `artist_lang`;
CREATE TABLE `artist_lang` (
    `artist_id` INT NOT NULL COMMENT '艺术家ID，关联artist表',
    `lang_code` CHAR(2) NOT NULL COMMENT '语言代码，en/es/fr/de/ja/zh等',
    `bio_translated` TEXT COMMENT '艺术家简介的翻译版本',
    `name_translated` VARCHAR(100) DEFAULT NULL COMMENT '艺术家姓名翻译（某些语言需要）',
    PRIMARY KEY (`artist_id`, `lang_code`),
    CONSTRAINT `fk_artist_lang_artist` FOREIGN KEY (`artist_id`) REFERENCES `artist`(`artist_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='艺术家多语言表，支持不同语言的简介展示';

DROP TABLE IF EXISTS `category`;
CREATE TABLE `category` (
    `category_id` INT NOT NULL AUTO_INCREMENT COMMENT '分类ID，主键',
    `parent_id` INT DEFAULT NULL COMMENT '父分类ID，NULL表示顶级分类',
    `sort_order` INT DEFAULT 0 COMMENT '排序序号，数字越小越靠前',
    `image_url` VARCHAR(500) DEFAULT NULL COMMENT '分类图片URL',
    `is_active` BOOLEAN DEFAULT TRUE COMMENT '是否启用',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`category_id`),
    INDEX `idx_parent` (`parent_id`),
    INDEX `idx_sort` (`sort_order`),
    CONSTRAINT `fk_category_parent` FOREIGN KEY (`parent_id`) REFERENCES `category`(`category_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品分类表，支持无限级分类（如陶瓷>碗具>釉彩碗）';

DROP TABLE IF EXISTS `category_lang`;
CREATE TABLE `category_lang` (
    `category_id` INT NOT NULL COMMENT '分类ID，关联category表',
    `lang_code` CHAR(2) NOT NULL COMMENT '语言代码',
    `name` VARCHAR(100) NOT NULL COMMENT '分类名称（翻译后）',
    `slug` VARCHAR(120) NOT NULL COMMENT 'SEO友好URL标识，如handmade-ceramic-bowls',
    `description` VARCHAR(500) DEFAULT NULL COMMENT '分类描述（翻译后）',
    PRIMARY KEY (`category_id`, `lang_code`),
    UNIQUE KEY `uk_slug_lang` (`slug`, `lang_code`),
    INDEX `idx_slug` (`slug`),
    CONSTRAINT `fk_category_lang_category` FOREIGN KEY (`category_id`) REFERENCES `category`(`category_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='分类多语言表，存储各语言版本的分类型录和SEO链接';

DROP TABLE IF EXISTS `product`;
CREATE TABLE `product` (
    `product_id` INT NOT NULL AUTO_INCREMENT COMMENT '商品ID，主键',
    `sku_prefix` VARCHAR(30) NOT NULL COMMENT '商品编号前缀，如HAN-001，全局唯一',
    `artist_id` INT DEFAULT NULL COMMENT '关联的艺术家ID',
    `category_id` INT DEFAULT NULL COMMENT '主分类ID',
    `base_price` DECIMAL(10,2) NOT NULL COMMENT '基准价格（美元USD），实际销售价=基准价+SKU价格调整',
    `weight_kg` DECIMAL(6,2) DEFAULT NULL COMMENT '商品重量（千克），用于运费计算',
    `production_days` SMALLINT DEFAULT NULL COMMENT '手工制作所需天数，如15表示需要15天制作',
    `is_limited_edition` BOOLEAN DEFAULT FALSE COMMENT '是否为限量版',
    `total_quantity` INT DEFAULT NULL COMMENT '计划总制作数量（含已售），仅限量版有意义',
    `sold_quantity` INT DEFAULT 0 COMMENT '已售数量',
    `is_customizable` BOOLEAN DEFAULT FALSE COMMENT '是否支持定制（刻字/颜色选择等）',
    `status` ENUM('draft', 'active', 'discontinued') DEFAULT 'draft' COMMENT '商品状态：draft草稿/active在售/discontinued停售',
    `seo_title` VARCHAR(120) DEFAULT NULL COMMENT 'SEO标题标签',
    `seo_description` VARCHAR(255) DEFAULT NULL COMMENT 'SEO描述标签',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`product_id`),
    UNIQUE KEY `uk_sku_prefix` (`sku_prefix`),
    INDEX `idx_artist` (`artist_id`),
    INDEX `idx_category` (`category_id`),
    INDEX `idx_status` (`status`),
    INDEX `idx_limited` (`is_limited_edition`),
    CONSTRAINT `fk_product_artist` FOREIGN KEY (`artist_id`) REFERENCES `artist`(`artist_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `fk_product_category` FOREIGN KEY (`category_id`) REFERENCES `category`(`category_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品主表，存储手工艺术品的通用信息和基础定价';

DROP TABLE IF EXISTS `product_lang`;
CREATE TABLE `product_lang` (
    `product_id` INT NOT NULL COMMENT '商品ID，关联product表',
    `lang_code` CHAR(2) NOT NULL COMMENT '语言代码',
    `name` VARCHAR(200) NOT NULL COMMENT '商品名称（翻译后）',
    `description` TEXT COMMENT '商品描述（翻译后）',
    `material` TEXT COMMENT '材质说明，如"陶瓷、釉料"',
    `dimensions` VARCHAR(100) DEFAULT NULL COMMENT '尺寸，如"15x10x5 cm"',
    `care_instructions` TEXT COMMENT '保养说明',
    `story` TEXT COMMENT '手工艺品背后的故事（增加情感连接）',
    PRIMARY KEY (`product_id`, `lang_code`),
    FULLTEXT INDEX `ft_search` (`name`, `description`),
    CONSTRAINT `fk_product_lang_product` FOREIGN KEY (`product_id`) REFERENCES `product`(`product_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品多语言表，存储各语言版本的商品信息，支持全文搜索';

DROP TABLE IF EXISTS `product_sku`;
CREATE TABLE `product_sku` (
    `sku_id` INT NOT NULL AUTO_INCREMENT COMMENT 'SKU ID，主键',
    `product_id` INT NOT NULL COMMENT '所属商品ID',
    `sku_code` VARCHAR(50) NOT NULL COMMENT 'SKU编码，如HAN-001-BLUE-S，全局唯一',
    `attribute_json` JSON DEFAULT NULL COMMENT '属性JSON，如{"color":"蓝色","size":"M","material":"银"}',
    `price_adjust` DECIMAL(8,2) DEFAULT 0.00 COMMENT '价格调整额（美元），相对于商品基准价，可为正或负',
    `stock_quantity` INT NOT NULL DEFAULT 0 COMMENT '当前库存数量',
    `reserved_quantity` INT NOT NULL DEFAULT 0 COMMENT '预留库存（已下单未支付）',
    `limited_edition_number` VARCHAR(20) DEFAULT NULL COMMENT '限量版编号，如"23/100"',
    `individual_photo_url` VARCHAR(500) DEFAULT NULL COMMENT '单品实拍照片URL（突出手工艺品的独特性）',
    `craftsman_note` VARCHAR(500) DEFAULT NULL COMMENT '工匠备注，描述该单品的独特纹路或色彩差异',
    `is_available` BOOLEAN DEFAULT TRUE COMMENT '是否可售',
    `reorder_point` INT DEFAULT 0 COMMENT '再订货点（库存低于此值时提醒补货）',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`sku_id`),
    UNIQUE KEY `uk_sku_code` (`sku_code`),
    INDEX `idx_product` (`product_id`),
    INDEX `idx_stock` (`stock_quantity`),
    INDEX `idx_available` (`is_available`),
    INDEX `idx_limited_number` (`limited_edition_number`),
    CONSTRAINT `fk_product_sku_product` FOREIGN KEY (`product_id`) REFERENCES `product`(`product_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品SKU表，存储实际可销售的每个具体规格单品（颜色/尺寸组合）';

DROP TABLE IF EXISTS `currency_price`;
CREATE TABLE `currency_price` (
    `sku_id` INT NOT NULL COMMENT 'SKU ID',
    `currency_code` CHAR(3) NOT NULL COMMENT '货币代码，USD/EUR/GBP/CAD/AUD等',
    `price` DECIMAL(10,2) NOT NULL COMMENT '该货币下的销售价格',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '价格更新时间',
    PRIMARY KEY (`sku_id`, `currency_code`),
    INDEX `idx_currency` (`currency_code`),
    CONSTRAINT `fk_currency_price_sku` FOREIGN KEY (`sku_id`) REFERENCES `product_sku`(`sku_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='SKU多货币价格表，存储不同货币的展示价格（非实时汇率）';

DROP TABLE IF EXISTS `product_custom_option`;
CREATE TABLE `product_custom_option` (
    `option_id` INT NOT NULL AUTO_INCREMENT COMMENT '选项ID',
    `product_id` INT NOT NULL COMMENT '所属商品ID',
    `option_name` VARCHAR(100) NOT NULL COMMENT '选项名称，如"刻字内容"、"包装样式"',
    `option_type` ENUM('text', 'select', 'radio', 'checkbox') DEFAULT 'text' COMMENT '选项类型',
    `is_required` BOOLEAN DEFAULT FALSE COMMENT '是否必选',
    `price_extra` DECIMAL(8,2) DEFAULT 0.00 COMMENT '额外价格（美元）',
    `max_length` SMALLINT DEFAULT NULL COMMENT '文本最大长度（text类型时使用）',
    `sort_order` INT DEFAULT 0 COMMENT '排序',
    PRIMARY KEY (`option_id`),
    INDEX `idx_product` (`product_id`),
    CONSTRAINT `fk_custom_option_product` FOREIGN KEY (`product_id`) REFERENCES `product`(`product_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品定制选项表，支持刻字、包装等个性化需求';

DROP TABLE IF EXISTS `product_shipping_restriction`;
CREATE TABLE `product_shipping_restriction` (
    `restriction_id` INT NOT NULL AUTO_INCREMENT COMMENT '限制ID',
    `product_id` INT NOT NULL COMMENT '商品ID',
    `country_code` CHAR(2) NOT NULL COMMENT '限制国家代码',
    `restriction_reason` VARCHAR(255) DEFAULT NULL COMMENT '限制原因，如"木制品限制进口"',
    PRIMARY KEY (`restriction_id`),
    UNIQUE KEY `uk_product_country` (`product_id`, `country_code`),
    CONSTRAINT `fk_shipping_restriction_product` FOREIGN KEY (`product_id`) REFERENCES `product`(`product_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品物流限制表，记录某些商品不能运往的国家';

DROP TABLE IF EXISTS `customer`;
CREATE TABLE `customer` (
    `customer_id` INT NOT NULL AUTO_INCREMENT COMMENT '客户ID，主键',
    `email` VARCHAR(150) NOT NULL COMMENT '电子邮箱（登录账号）',
    `password_hash` VARCHAR(255) NOT NULL COMMENT '密码哈希值（bcrypt/argon2）',
    `first_name` VARCHAR(50) DEFAULT NULL COMMENT '名',
    `last_name` VARCHAR(50) DEFAULT NULL COMMENT '姓',
    `avatar_url` VARCHAR(500) DEFAULT NULL COMMENT '头像URL',
    `registration_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '注册日期',
    `last_login` TIMESTAMP NULL DEFAULT NULL COMMENT '最后登录时间',
    `preferred_currency` CHAR(3) DEFAULT 'USD' COMMENT '首选货币',
    `preferred_lang` CHAR(2) DEFAULT 'en' COMMENT '首选语言',
    `newsletter_subscribed` BOOLEAN DEFAULT FALSE COMMENT '是否订阅邮件营销',
    `email_verified` BOOLEAN DEFAULT FALSE COMMENT '邮箱是否已验证',
    `status` ENUM('active', 'inactive', 'banned') DEFAULT 'active' COMMENT '账户状态',
    `reset_token` VARCHAR(100) DEFAULT NULL COMMENT '密码重置令牌',
    `reset_expires` TIMESTAMP NULL DEFAULT NULL COMMENT '重置令牌过期时间',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`customer_id`),
    UNIQUE KEY `uk_email` (`email`),
    INDEX `idx_status` (`status`),
    INDEX `idx_registration` (`registration_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='客户信息表，存储注册用户的基本信息';

DROP TABLE IF EXISTS `address`;
CREATE TABLE `address` (
    `address_id` INT NOT NULL AUTO_INCREMENT COMMENT '地址ID，主键',
    `customer_id` INT NOT NULL COMMENT '所属客户ID',
    `address_type` ENUM('shipping', 'billing') DEFAULT 'shipping' COMMENT '地址类型：shipping送货地址/billing账单地址',
    `recipient_name` VARCHAR(100) NOT NULL COMMENT '收件人姓名',
    `phone_number` VARCHAR(30) DEFAULT NULL COMMENT '联系电话',
    `country_code` CHAR(2) NOT NULL COMMENT '国家代码',
    `state_province` VARCHAR(50) DEFAULT NULL COMMENT '州/省',
    `city` VARCHAR(50) NOT NULL COMMENT '城市',
    `postal_code` VARCHAR(20) DEFAULT NULL COMMENT '邮政编码',
    `street_address` VARCHAR(255) NOT NULL COMMENT '街道地址',
    `apartment` VARCHAR(50) DEFAULT NULL COMMENT '公寓/单元号',
    `is_default` BOOLEAN DEFAULT FALSE COMMENT '是否为默认地址',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`address_id`),
    INDEX `idx_customer` (`customer_id`),
    INDEX `idx_country` (`country_code`),
    INDEX `idx_default` (`is_default`),
    CONSTRAINT `fk_address_customer` FOREIGN KEY (`customer_id`) REFERENCES `customer`(`customer_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='客户地址表，支持多个送货地址和账单地址';

DROP TABLE IF EXISTS `orders`;
CREATE TABLE `orders` (
    `order_id` INT NOT NULL AUTO_INCREMENT COMMENT '订单ID，主键',
    `customer_id` INT DEFAULT NULL COMMENT '客户ID（未登录用户可为NULL）',
    `order_number` VARCHAR(30) NOT NULL COMMENT '订单号，全局唯一，如ORD-20231215-0001',
    `order_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '下单时间',
    `currency_code` CHAR(3) DEFAULT 'USD' COMMENT '订单使用的货币',
    `exchange_rate` DECIMAL(10,6) DEFAULT NULL COMMENT '下单时相对于美元汇率的汇率（用于财务记录）',
    `subtotal` DECIMAL(10,2) NOT NULL COMMENT '商品小计（不含运费和税费）',
    `shipping_fee` DECIMAL(8,2) DEFAULT 0.00 COMMENT '运费',
    `tax_amount` DECIMAL(8,2) DEFAULT 0.00 COMMENT '税费',
    `discount_amount` DECIMAL(8,2) DEFAULT 0.00 COMMENT '折扣金额',
    `total_amount` DECIMAL(10,2) NOT NULL COMMENT '订单总金额（小计+运费+税费-折扣）',
    `payment_method` VARCHAR(50) DEFAULT NULL COMMENT '支付方式，如stripe/paypal',
    `payment_status` ENUM('pending', 'paid', 'failed', 'refunded', 'partially_refunded') DEFAULT 'pending' COMMENT '支付状态',
    `shipping_method` VARCHAR(50) DEFAULT NULL COMMENT '配送方式，如dhl_express/fedex_priority',
    `shipping_status` ENUM('pending', 'processing', 'shipped', 'delivered', 'returned', 'cancelled') DEFAULT 'pending' COMMENT '配送状态',
    `tracking_number` VARCHAR(100) DEFAULT NULL COMMENT '物流单号',
    `shipping_address_id` INT NOT NULL COMMENT '配送地址ID',
    `billing_address_id` INT NOT NULL COMMENT '账单地址ID',
    `customer_note` TEXT COMMENT '客户备注',
    `admin_note` TEXT COMMENT '管理员备注',
    `paid_at` TIMESTAMP NULL DEFAULT NULL COMMENT '支付完成时间',
    `shipped_at` TIMESTAMP NULL DEFAULT NULL COMMENT '发货时间',
    `delivered_at` TIMESTAMP NULL DEFAULT NULL COMMENT '送达时间',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`order_id`),
    UNIQUE KEY `uk_order_number` (`order_number`),
    INDEX `idx_customer` (`customer_id`),
    INDEX `idx_order_date` (`order_date`),
    INDEX `idx_payment_status` (`payment_status`),
    INDEX `idx_shipping_status` (`shipping_status`),
    INDEX `idx_shipping_address` (`shipping_address_id`),
    INDEX `idx_billing_address` (`billing_address_id`),
    CONSTRAINT `fk_orders_customer` FOREIGN KEY (`customer_id`) REFERENCES `customer`(`customer_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `fk_orders_shipping_address` FOREIGN KEY (`shipping_address_id`) REFERENCES `address`(`address_id`) ON UPDATE CASCADE,
    CONSTRAINT `fk_orders_billing_address` FOREIGN KEY (`billing_address_id`) REFERENCES `address`(`address_id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单主表，存储每一笔交易的汇总信息';

DROP TABLE IF EXISTS `order_item`;
CREATE TABLE `order_item` (
    `order_item_id` INT NOT NULL AUTO_INCREMENT COMMENT '订单明细ID，主键',
    `order_id` INT NOT NULL COMMENT '所属订单ID',
    `sku_id` INT NOT NULL COMMENT 'SKU ID',
    `quantity` INT NOT NULL COMMENT '购买数量',
    `unit_price` DECIMAL(10,2) NOT NULL COMMENT '下单时单价（快照，避免价格变动影响历史订单）',
    `unit_tax` DECIMAL(8,2) DEFAULT 0.00 COMMENT '单件税费',
    `unit_discount` DECIMAL(8,2) DEFAULT 0.00 COMMENT '单件折扣',
    `product_name_snapshot` VARCHAR(200) NOT NULL COMMENT '商品名称快照（下单时的名称）',
    `sku_attributes_snapshot` VARCHAR(255) DEFAULT NULL COMMENT 'SKU属性快照，如"颜色:蓝, 尺寸:M"',
    `custom_options_snapshot` JSON DEFAULT NULL COMMENT '定制选项快照，如{"刻字内容":"Happy Birthday"}',
    `total_price` DECIMAL(10,2) GENERATED ALWAYS AS ((`unit_price` - `unit_discount` + `unit_tax`) * `quantity`) STORED COMMENT '单项总价（计算列）',
    PRIMARY KEY (`order_item_id`),
    INDEX `idx_order` (`order_id`),
    INDEX `idx_sku` (`sku_id`),
    CONSTRAINT `fk_order_item_order` FOREIGN KEY (`order_id`) REFERENCES `orders`(`order_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_order_item_sku` FOREIGN KEY (`sku_id`) REFERENCES `product_sku`(`sku_id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单明细表，存储订单中的每个商品项';

DROP TABLE IF EXISTS `review`;
CREATE TABLE `review` (
    `review_id` INT NOT NULL AUTO_INCREMENT COMMENT '评价ID，主键',
    `product_id` INT NOT NULL COMMENT '商品ID',
    `customer_id` INT NOT NULL COMMENT '客户ID',
    `order_id` INT NOT NULL COMMENT '订单ID（确保购买后才能评价）',
    `rating` TINYINT NOT NULL COMMENT '评分：1-5星',
    `title` VARCHAR(100) DEFAULT NULL COMMENT '评价标题',
    `comment` TEXT COMMENT '评价内容',
    `uploaded_image_urls` JSON DEFAULT NULL COMMENT '上传的图片URL数组，如["url1","url2"]',
    `is_verified_purchase` BOOLEAN DEFAULT TRUE COMMENT '是否为已购买验证用户',
    `status` ENUM('pending', 'approved', 'rejected', 'reported') DEFAULT 'pending' COMMENT '审核状态',
    `reply` TEXT COMMENT '商家回复内容',
    `reply_at` TIMESTAMP NULL DEFAULT NULL COMMENT '商家回复时间',
    `helpful_count` INT DEFAULT 0 COMMENT '有帮助点赞数',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '评价时间',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`review_id`),
    INDEX `idx_product` (`product_id`),
    INDEX `idx_customer` (`customer_id`),
    INDEX `idx_rating` (`rating`),
    INDEX `idx_status` (`status`),
    INDEX `idx_created` (`created_at`),
    CONSTRAINT `fk_review_product` FOREIGN KEY (`product_id`) REFERENCES `product`(`product_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_review_customer` FOREIGN KEY (`customer_id`) REFERENCES `customer`(`customer_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_review_order` FOREIGN KEY (`order_id`) REFERENCES `orders`(`order_id`) ON UPDATE CASCADE,
    CONSTRAINT `chk_rating` CHECK (`rating` BETWEEN 1 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品评价表，存储客户对商品的评分和评论';

DROP TABLE IF EXISTS `inventory_log`;
CREATE TABLE `inventory_log` (
    `log_id` INT NOT NULL AUTO_INCREMENT COMMENT '日志ID，主键',
    `sku_id` INT NOT NULL COMMENT 'SKU ID',
    `change_quantity` INT NOT NULL COMMENT '变更数量（正数为增加库存，负数为减少）',
    `old_quantity` INT NOT NULL COMMENT '变更前数量',
    `new_quantity` INT NOT NULL COMMENT '变更后数量',
    `change_reason` ENUM('order_placed', 'order_cancelled', 'payment_confirmed', 'restock', 'return', 'adjustment', 'artist_create', 'damaged') NOT NULL COMMENT '变更原因',
    `reference_id` VARCHAR(50) DEFAULT NULL COMMENT '关联单据号，如订单号或入库单号',
    `operator_type` ENUM('customer', 'admin', 'system') DEFAULT 'system' COMMENT '操作者类型',
    `operator_id` INT DEFAULT NULL COMMENT '操作者ID（admin用户ID或customer_id）',
    `notes` VARCHAR(500) DEFAULT NULL COMMENT '备注说明',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '变更时间',
    PRIMARY KEY (`log_id`),
    INDEX `idx_sku` (`sku_id`),
    INDEX `idx_reason` (`change_reason`),
    INDEX `idx_created` (`created_at`),
    INDEX `idx_reference` (`reference_id`),
    CONSTRAINT `fk_inventory_log_sku` FOREIGN KEY (`sku_id`) REFERENCES `product_sku`(`sku_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='库存变更日志表，记录所有库存变动的详细历史';

DROP TABLE IF EXISTS `cart`;
CREATE TABLE `cart` (
    `cart_id` INT NOT NULL AUTO_INCREMENT COMMENT '购物车ID',
    `customer_id` INT DEFAULT NULL COMMENT '客户ID（未登录用户可为NULL）',
    `session_token` VARCHAR(100) DEFAULT NULL COMMENT '会话令牌（未登录用户使用）',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`cart_id`),
    INDEX `idx_customer` (`customer_id`),
    INDEX `idx_session` (`session_token`),
    CONSTRAINT `fk_cart_customer` FOREIGN KEY (`customer_id`) REFERENCES `customer`(`customer_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='购物车主表';

DROP TABLE IF EXISTS `cart_item`;
CREATE TABLE `cart_item` (
    `cart_item_id` INT NOT NULL AUTO_INCREMENT COMMENT '购物车明细ID',
    `cart_id` INT NOT NULL COMMENT '购物车ID',
    `sku_id` INT NOT NULL COMMENT 'SKU ID',
    `quantity` INT NOT NULL DEFAULT 1 COMMENT '数量',
    `custom_options_json` JSON DEFAULT NULL COMMENT '定制选项JSON',
    `added_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '添加时间',
    PRIMARY KEY (`cart_item_id`),
    INDEX `idx_cart` (`cart_id`),
    INDEX `idx_sku` (`sku_id`),
    CONSTRAINT `fk_cart_item_cart` FOREIGN KEY (`cart_id`) REFERENCES `cart`(`cart_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_cart_item_sku` FOREIGN KEY (`sku_id`) REFERENCES `product_sku`(`sku_id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='购物车明细表';

INSERT INTO `artist` (`name`, `country_code`, `bio`, `profile_image_url`, `instagram_handle`, `featured`) VALUES
('Elena Rodriguez', 'ES', 'Elena is a third-generation ceramic artist from Valencia, Spain. Her hand-painted tile techniques have been passed down through her family for over 60 years.', '/images/artists/elena.jpg', 'elena_ceramics', TRUE),
('Kenji Tanaka', 'JP', 'Master woodworker from Kyoto, specializing in hand-carved tea utensils using traditional Japanese methods. Each piece takes 2-3 weeks to complete.', '/images/artists/kenji.jpg', 'kenji_woodart', TRUE),
('Maria Souza', 'BR', 'Brazilian textile artist creating vibrant tapestries from sustainable natural fibers. Her work celebrates indigenous patterns and modern design.', '/images/artists/maria.jpg', 'maria_textiles', FALSE),
('David Chen', 'CN', 'Jade carving specialist from Shanghai. David combines traditional Chinese motifs with contemporary sculpture techniques.', '/images/artists/david.jpg', 'david_jade', TRUE);

INSERT INTO `artist_lang` (`artist_id`, `lang_code`, `bio_translated`, `name_translated`) VALUES
(1, 'es', 'Elena es una artista cerámica de tercera generación de Valencia, España.', 'Elena Rodríguez'),
(1, 'zh', 'Elena是来自西班牙瓦伦西亚的第三代陶瓷艺术家。', '埃琳娜·罗德里格斯'),
(2, 'ja', '京都出身の木工芸マスター。伝統的な日本技法を用いた茶道具を専門としています。', '田中健二'),
(2, 'zh', '来自京都的木工大师，专攻传统日本手雕茶具。', '田中健二');

INSERT INTO `category` (`parent_id`, `sort_order`, `image_url`) VALUES
(NULL, 1, '/images/categories/ceramics.jpg'),
(NULL, 2, '/images/categories/woodwork.jpg'),
(NULL, 3, '/images/categories/textiles.jpg'),
(1, 1, '/images/categories/bowls.jpg'),
(1, 2, '/images/categories/vases.jpg'),
(2, 1, '/images/categories/tea_set.jpg');

INSERT INTO `category_lang` (`category_id`, `lang_code`, `name`, `slug`, `description`) VALUES
(1, 'en', 'Ceramics', 'ceramics', 'Handcrafted ceramic art pieces'),
(1, 'zh', '陶瓷', 'ceramics-zh', '手工陶瓷艺术品'),
(2, 'en', 'Woodwork', 'woodwork', 'Hand-carved wooden artworks'),
(2, 'zh', '木制品', 'woodwork-zh', '手工木雕艺术品'),
(3, 'en', 'Textiles', 'textiles', 'Woven tapestries and fiber art'),
(3, 'zh', '纺织品', 'textiles-zh', '编织挂毯和纤维艺术'),
(4, 'en', 'Bowls', 'bowls', 'Decorative and functional ceramic bowls'),
(4, 'zh', '碗具', 'bowls-zh', '装饰性和功能性陶瓷碗'),
(5, 'en', 'Vases', 'vases', 'Hand-thrown ceramic vases'),
(5, 'zh', '花瓶', 'vases-zh', '手工陶瓷花瓶'),
(6, 'en', 'Tea Sets', 'tea-sets', 'Traditional wooden tea ceremony sets'),
(6, 'zh', '茶具', 'tea-sets-zh', '传统木制茶具套装');

INSERT INTO `product` (`sku_prefix`, `artist_id`, `category_id`, `base_price`, `weight_kg`, `production_days`, `is_limited_edition`, `total_quantity`, `is_customizable`, `status`, `seo_title`, `seo_description`) VALUES
('HAN-CER-001', 1, 4, 89.00, 0.45, 7, FALSE, NULL, TRUE, 'active', 'Hand-painted Ceramic Bowl - Traditional Spanish Design', 'Beautiful hand-painted ceramic bowl from Valencia, Spain.'),
('HAN-WD-002', 2, 6, 245.00, 0.32, 14, TRUE, 50, TRUE, 'active', 'Japanese Wooden Tea Set - Hand-carved Matcha Set', 'Authentic Japanese tea ceremony set made from premium cherry wood.'),
('HAN-TX-003', 3, 3, 159.00, 0.78, 10, FALSE, NULL, FALSE, 'active', 'Brazilian Woven Tapestry - Rainbow Mountain', 'Vibrant hand-woven wall hanging made from sustainable natural fibers.'),
('HAN-JD-004', 4, 5, 399.00, 0.12, 21, TRUE, 20, FALSE, 'active', 'Jade Carved Vase - Dragon Motif', 'Exquisite jade vase with hand-carved dragon patterns.');

INSERT INTO `product_lang` (`product_id`, `lang_code`, `name`, `description`, `material`, `dimensions`, `care_instructions`) VALUES
(1, 'en', 'Hand-painted Ceramic Bowl - Blue Floral', 'Beautiful hand-painted ceramic bowl featuring traditional Spanish floral patterns.', 'Ceramic, lead-free glaze', '20cm diameter x 8cm height', 'Hand wash recommended. Microwave and dishwasher safe.'),
(1, 'zh', '手绘陶瓷碗 - 蓝色花卉', '精美手绘陶瓷碗，采用传统西班牙花卉图案。', '陶瓷，无铅釉', '直径20cm x 高8cm', '建议手洗。可用微波炉和洗碗机。'),
(2, 'en', 'Japanese Wooden Tea Set - Matcha Master', 'Complete matcha tea set including chawan (tea bowl), chasen (whisk), and chashaku (scoop).', 'Cherry wood, natural beeswax finish', 'Bowl: 12cm diameter x 9cm height', 'Hand wash only. Apply food-grade mineral oil monthly.'),
(2, 'zh', '日本木制茶具 - 抹茶大师', '完整的抹茶茶具套装，包括茶碗、茶筅和茶杓。', '樱桃木，天然蜂蜡涂层', '茶碗: 直径12cm x 高9cm', '只能手洗。每月涂抹食品级矿物油。');

INSERT INTO `product_sku` (`product_id`, `sku_code`, `attribute_json`, `price_adjust`, `stock_quantity`, `limited_edition_number`, `craftsman_note`, `is_available`) VALUES
(1, 'HAN-CER-001-BLUE', '{"color": "Blue Floral", "style": "Traditional"}', 0.00, 12, NULL, 'Slight variation in the blue glaze depth - each piece is unique', TRUE),
(1, 'HAN-CER-001-GREEN', '{"color": "Green Vine", "style": "Traditional"}', 5.00, 8, NULL, 'Green glaze with subtle crackle effect', TRUE),
(2, 'HAN-WD-002-MATCH A', '{"set_type": "Matcha Master", "includes": "bowl,whisk,scoop"}', 0.00, 25, '12/50', 'Hand-carved by Master Kenji Tanaka', TRUE),
(2, 'HAN-WD-002-MATCH B', '{"set_type": "Matcha Deluxe", "includes": "bowl,whisk,scoop,holder"}', 30.00, 15, '8/50', 'Limited edition with special engraving', TRUE),
(3, 'HAN-TX-003-RAINBOW', '{"pattern": "Rainbow Mountain", "size": "60x90cm"}', 0.00, 5, NULL, 'Hand-woven with natural dyes', TRUE),
(4, 'HAN-JD-004-DRAGON', '{"motif": "Dragon", "jade_type": "Nephrite"}', 0.00, 8, '5/20', 'Certified genuine jade from Hetian', TRUE);

INSERT INTO `currency_price` (`sku_id`, `currency_code`, `price`) VALUES
(1, 'USD', 89.00), (1, 'EUR', 82.00), (1, 'GBP', 70.00),
(2, 'USD', 94.00), (2, 'EUR', 86.50), (2, 'GBP', 74.00),
(3, 'USD', 245.00), (3, 'EUR', 225.00), (3, 'GBP', 192.00),
(4, 'USD', 275.00), (4, 'EUR', 253.00), (4, 'GBP', 216.00),
(5, 'USD', 159.00), (5, 'EUR', 146.00), (5, 'GBP', 125.00),
(6, 'USD', 399.00), (6, 'EUR', 367.00), (6, 'GBP', 313.00);

INSERT INTO `product_custom_option` (`product_id`, `option_name`, `option_type`, `is_required`, `price_extra`, `max_length`, `sort_order`) VALUES
(1, 'Engraving Text', 'text', FALSE, 15.00, 20, 1),
(1, 'Gift Box', 'checkbox', FALSE, 8.00, NULL, 2),
(2, 'Engraving on Chashaku', 'text', FALSE, 20.00, 15, 1),
(2, 'Custom Box', 'checkbox', FALSE, 12.00, NULL, 2);

INSERT INTO `customer` (`email`, `password_hash`, `first_name`, `last_name`, `preferred_currency`, `preferred_lang`, `newsletter_subscribed`, `email_verified`, `status`) VALUES
('john.doe@example.com', '$2y$10$encrypted_hash_here', 'John', 'Doe', 'USD', 'en', TRUE, TRUE, 'active'),
('jane.smith@example.com', '$2y$10$encrypted_hash_here', 'Jane', 'Smith', 'EUR', 'es', FALSE, TRUE, 'active'),
('customer@example.com', '$2y$10$encrypted_hash_here', 'Test', 'Customer', 'USD', 'zh', TRUE, TRUE, 'active');

INSERT INTO `address` (`customer_id`, `address_type`, `recipient_name`, `phone_number`, `country_code`, `state_province`, `city`, `postal_code`, `street_address`, `is_default`) VALUES
(1, 'shipping', 'John Doe', '+1234567890', 'US', 'California', 'Los Angeles', '90001', '123 Main Street', TRUE),
(1, 'billing', 'John Doe', '+1234567890', 'US', 'California', 'Los Angeles', '90001', '123 Main Street', TRUE),
(2, 'shipping', 'Jane Smith', '+442012345678', 'GB', 'London', 'London', 'SW1A 1AA', '10 Downing Street', TRUE);


INSERT INTO `orders` (`customer_id`, `order_number`, `order_date`, `currency_code`, `exchange_rate`, `subtotal`, `shipping_fee`, `tax_amount`, `discount_amount`, `total_amount`, `payment_status`, `shipping_status`, `shipping_address_id`, `billing_address_id`, `paid_at`) VALUES
(1, 'ORD-20240520-0001', '2024-05-20 10:30:00', 'USD', 1.0000, 89.00, 10.00, 8.01, 0.00, 107.01, 'paid', 'shipped', 1, 2, '2024-05-20 10:35:00'),
(2, 'ORD-20240515-0002', '2024-05-15 14:20:00', 'EUR', 0.9200, 367.00, 15.00, 33.03, 20.00, 395.03, 'paid', 'delivered', 3, 3, '2024-05-15 14:25:00'),
(1, 'ORD-20240510-0003', '2024-05-10 09:15:00', 'USD', 1.0000, 245.00, 12.00, 22.05, 0.00, 279.05, 'paid', 'delivered', 1, 2, '2024-05-10 09:20:00');

INSERT INTO `order_item` (`order_id`, `sku_id`, `quantity`, `unit_price`, `unit_tax`, `unit_discount`, `product_name_snapshot`, `sku_attributes_snapshot`, `custom_options_snapshot`) VALUES
(1, 1, 1, 89.00, 8.01, 0.00, 'Hand-painted Ceramic Bowl - Blue Floral', 'color: Blue Floral, style: Traditional', NULL),
(2, 5, 1, 159.00, 14.31, 0.00, 'Brazilian Woven Tapestry - Rainbow Mountain', 'pattern: Rainbow Mountain, size: 60x90cm', NULL),
(2, 4, 1, 275.00, 24.75, 20.00, 'Japanese Wooden Tea Set - Matcha Master', 'set_type: Matcha Deluxe', '{"Engraving on Chashaku": "Happy Birthday"}'),
(3, 3, 1, 245.00, 22.05, 0.00, 'Japanese Wooden Tea Set - Matcha Master', 'set_type: Matcha Master', NULL);

INSERT INTO `review` (`product_id`, `customer_id`, `order_id`, `rating`, `title`, `comment`, `status`, `helpful_count`) VALUES
(1, 1, 1, 5, 'Beautiful bowl!', 'The craftsmanship is amazing. The colors are vibrant and it arrived safely.', 'approved', 12),
(2, 1, 3, 4, 'Great tea set', 'Beautifully crafted tea set. The wood quality is excellent.', 'approved', 5),
(3, 2, 2, 5, 'Stunning tapestry', 'The colors are even more beautiful in person. A true work of art.', 'approved', 8);

INSERT INTO `inventory_log` (`sku_id`, `change_quantity`, `old_quantity`, `new_quantity`, `change_reason`, `reference_id`, `operator_type`, `notes`) VALUES
(1, -1, 12, 11, 'order_placed', 'ORD-20240520-0001', 'system', 'Order placed by customer'),
(3, -1, 25, 24, 'order_placed', 'ORD-20240510-0003', 'system', 'Order placed by customer'),
(5, -1, 5, 4, 'order_placed', 'ORD-20240515-0002', 'system', 'Order placed by customer'),
(4, -1, 15, 14, 'order_placed', 'ORD-20240515-0002', 'system', 'Order placed by customer');

INSERT INTO `cart` (`customer_id`, `session_token`) VALUES
(1, NULL),
(NULL, 'session_abc123def456');

INSERT INTO `cart_item` (`cart_id`, `sku_id`, `quantity`, `custom_options_json`) VALUES
(1, 2, 1, '{"Gift Box": true, "Engraving Text": "For Mom"}'),
(2, 1, 2, NULL);

SELECT '数据库创建完成！' AS message;
SELECT COUNT(*) AS artist_count FROM artist;
SELECT COUNT(*) AS category_count FROM category;
SELECT COUNT(*) AS product_count FROM product;
SELECT COUNT(*) AS sku_count FROM product_sku;
SELECT COUNT(*) AS customer_count FROM customer;
SELECT COUNT(*) AS order_count FROM orders;
SELECT COUNT(*) AS review_count FROM review;