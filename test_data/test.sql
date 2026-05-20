DROP DATABASE IF EXISTS `employee_management`;
CREATE DATABASE `employee_management` 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE `employee_management`;

DROP TABLE IF EXISTS `company`;
CREATE TABLE `company` (
    `company_id` INT NOT NULL AUTO_INCREMENT COMMENT '公司ID，主键',
    `company_code` VARCHAR(20) NOT NULL COMMENT '公司编码，唯一标识',
    `company_name` VARCHAR(100) NOT NULL COMMENT '公司名称',
    `short_name` VARCHAR(50) DEFAULT NULL COMMENT '公司简称',
    `legal_representative` VARCHAR(50) DEFAULT NULL COMMENT '法定代表人',
    `unified_social_credit_code` VARCHAR(18) DEFAULT NULL COMMENT '统一社会信用代码',
    `registered_address` VARCHAR(255) DEFAULT NULL COMMENT '注册地址',
    `office_address` VARCHAR(255) DEFAULT NULL COMMENT '办公地址',
    `contact_phone` VARCHAR(20) DEFAULT NULL COMMENT '联系电话',
    `contact_email` VARCHAR(100) DEFAULT NULL COMMENT '联系邮箱',
    `logo_url` VARCHAR(500) DEFAULT NULL COMMENT '公司Logo URL',
    `status` ENUM('active', 'inactive') DEFAULT 'active' COMMENT '公司状态',
    `founding_date` DATE DEFAULT NULL COMMENT '成立日期',
    `business_scope` TEXT COMMENT '经营范围',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`company_id`),
    UNIQUE KEY `uk_company_code` (`company_code`),
    UNIQUE KEY `uk_credit_code` (`unified_social_credit_code`)
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '公司信息表';

DROP TABLE IF EXISTS `department`;
CREATE TABLE `department` (
    `dept_id` INT NOT NULL AUTO_INCREMENT COMMENT '部门ID，主键',
    `company_id` INT NOT NULL COMMENT '所属公司ID',
    `parent_dept_id` INT DEFAULT NULL COMMENT '上级部门ID，NULL表示顶级部门',
    `dept_code` VARCHAR(30) NOT NULL COMMENT '部门编码',
    `dept_name` VARCHAR(100) NOT NULL COMMENT '部门名称',
    `dept_leader_id` INT DEFAULT NULL COMMENT '部门负责人ID（关联employee表）',
    `leader_position` VARCHAR(50) DEFAULT NULL COMMENT '负责人职位',
    `phone` VARCHAR(20) DEFAULT NULL COMMENT '部门电话',
    `email` VARCHAR(100) DEFAULT NULL COMMENT '部门邮箱',
    `sort_order` INT DEFAULT 0 COMMENT '排序序号',
    `dept_path` VARCHAR(500) DEFAULT NULL COMMENT '部门路径，如/1/2/3/',
    `status` ENUM('active', 'inactive') DEFAULT 'active' COMMENT '部门状态',
    `description` VARCHAR(500) DEFAULT NULL COMMENT '部门描述',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`dept_id`),
    UNIQUE KEY `uk_dept_code` (`company_id`, `dept_code`),
    INDEX `idx_company` (`company_id`),
    INDEX `idx_parent` (`parent_dept_id`),
    INDEX `idx_leader` (`dept_leader_id`),
    INDEX `idx_path` (`dept_path`),
    FOREIGN KEY (`company_id`) REFERENCES `company` (`company_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`parent_dept_id`) REFERENCES `department` (`dept_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '部门表，存储公司组织架构树';

DROP TABLE IF EXISTS `position`;
CREATE TABLE `position` (
    `position_id` INT NOT NULL AUTO_INCREMENT COMMENT '岗位ID，主键',
    `company_id` INT NOT NULL COMMENT '所属公司ID',
    `position_code` VARCHAR(30) NOT NULL COMMENT '岗位编码',
    `position_name` VARCHAR(100) NOT NULL COMMENT '岗位名称',
    `position_level` ENUM('intern', 'junior', 'middle', 'senior', 'lead', 'manager', 'director', 'vp', 'c_level') DEFAULT 'junior' COMMENT '岗位级别',
    `parent_position_id` INT DEFAULT NULL COMMENT '上级岗位ID（用于岗位晋升路径）',
    `job_description` TEXT COMMENT '岗位职责描述',
    `job_requirements` TEXT COMMENT '岗位任职要求',
    `min_salary` DECIMAL(12, 2) DEFAULT NULL COMMENT '该岗位最低薪资',
    `max_salary` DECIMAL(12, 2) DEFAULT NULL COMMENT '该岗位最高薪资',
    `status` ENUM('active', 'inactive') DEFAULT 'active' COMMENT '岗位状态',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`position_id`),
    UNIQUE KEY `uk_position_code` (`company_id`, `position_code`),
    INDEX `idx_company` (`company_id`),
    INDEX `idx_level` (`position_level`),
    FOREIGN KEY (`company_id`) REFERENCES `company` (`company_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`parent_position_id`) REFERENCES `position` (`position_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '岗位表，定义公司所有岗位信息';

DROP TABLE IF EXISTS `employee`;
CREATE TABLE `employee` (
    `employee_id` INT NOT NULL AUTO_INCREMENT COMMENT '员工ID，主键',
    `employee_no` VARCHAR(30) NOT NULL COMMENT '员工工号，公司唯一',
    `company_id` INT NOT NULL COMMENT '所属公司ID',
    `dept_id` INT NOT NULL COMMENT '所属部门ID',
    `position_id` INT NOT NULL COMMENT '当前岗位ID',
    `id_card_type` ENUM('id_card', 'passport', 'driver_license', 'other') DEFAULT 'id_card' COMMENT '证件类型',
    `id_card_number` VARCHAR(50) NOT NULL COMMENT '证件号码',
    `full_name` VARCHAR(50) NOT NULL COMMENT '员工姓名',
    `english_name` VARCHAR(50) DEFAULT NULL COMMENT '英文名',
    `gender` ENUM('male', 'female', 'other') DEFAULT NULL COMMENT '性别',
    `birth_date` DATE DEFAULT NULL COMMENT '出生日期',
    `nationality` VARCHAR(50) DEFAULT '中国' COMMENT '国籍',
    `ethnicity` VARCHAR(20) DEFAULT NULL COMMENT '民族',
    `marital_status` ENUM('single', 'married', 'divorced', 'widowed') DEFAULT NULL COMMENT '婚姻状况',
    `avatar_url` VARCHAR(500) DEFAULT NULL COMMENT '头像URL',
    `phone` VARCHAR(20) NOT NULL COMMENT '手机号码',
    `emergency_contact_name` VARCHAR(50) DEFAULT NULL COMMENT '紧急联系人姓名',
    `emergency_contact_phone` VARCHAR(20) DEFAULT NULL COMMENT '紧急联系人电话',
    `emergency_contact_relation` VARCHAR(20) DEFAULT NULL COMMENT '紧急联系人关系',
    `personal_email` VARCHAR(100) DEFAULT NULL COMMENT '个人邮箱',
    `work_email` VARCHAR(100) NOT NULL COMMENT '工作邮箱',
    `hire_date` DATE NOT NULL COMMENT '入职日期',
    `probation_end_date` DATE DEFAULT NULL COMMENT '试用期结束日期',
    `regularization_date` DATE DEFAULT NULL COMMENT '转正日期',
    `resignation_date` DATE DEFAULT NULL COMMENT '离职日期',
    `employment_status` ENUM('probation', 'active', 'resigned', 'terminated', 'leave', 'retired') DEFAULT 'probation' COMMENT '雇佣状态',
    `work_city` VARCHAR(50) DEFAULT NULL COMMENT '工作城市',
    `work_address` VARCHAR(255) DEFAULT NULL COMMENT '详细工作地址',
    `bank_name` VARCHAR(50) DEFAULT NULL COMMENT '开户银行',
    `bank_account` VARCHAR(50) DEFAULT NULL COMMENT '银行账号',
    `bank_account_name` VARCHAR(50) DEFAULT NULL COMMENT '银行账户名',
    `supervisor_id` INT DEFAULT NULL COMMENT '直属上级ID（关联employee表）',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`employee_id`),
    UNIQUE KEY `uk_employee_no` (`company_id`, `employee_no`),
    UNIQUE KEY `uk_work_email` (`company_id`, `work_email`),
    UNIQUE KEY `uk_id_card` (`id_card_number`),
    INDEX `idx_company` (`company_id`),
    INDEX `idx_dept` (`dept_id`),
    INDEX `idx_position` (`position_id`),
    INDEX `idx_supervisor` (`supervisor_id`),
    INDEX `idx_hire_date` (`hire_date`),
    INDEX `idx_status` (`employment_status`),
    INDEX `idx_phone` (`phone`),
    FOREIGN KEY (`company_id`) REFERENCES `company` (`company_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`dept_id`) REFERENCES `department` (`dept_id`) ON UPDATE CASCADE,
    FOREIGN KEY (`position_id`) REFERENCES `position` (`position_id`) ON UPDATE CASCADE,
    FOREIGN KEY (`supervisor_id`) REFERENCES `employee` (`employee_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '员工主表，存储所有员工的基本信息';

ALTER TABLE `department`
ADD CONSTRAINT `fk_dept_leader` FOREIGN KEY (`dept_leader_id`) REFERENCES `employee` (`employee_id`) ON DELETE SET NULL ON UPDATE CASCADE;

DROP TABLE IF EXISTS `employee_education`;
CREATE TABLE `employee_education` (
    `education_id` INT NOT NULL AUTO_INCREMENT COMMENT '教育经历ID',
    `employee_id` INT NOT NULL COMMENT '员工ID',
    `school_name` VARCHAR(100) NOT NULL COMMENT '学校名称',
    `major` VARCHAR(100) DEFAULT NULL COMMENT '专业',
    `degree` ENUM('high_school', 'associate', 'bachelor', 'master', 'doctor', 'other') DEFAULT NULL COMMENT '学历/学位',
    `start_date` DATE NOT NULL COMMENT '开始日期',
    `end_date` DATE DEFAULT NULL COMMENT '结束日期',
    `is_highest` BOOLEAN DEFAULT FALSE COMMENT '是否为最高学历',
    `certificate_url` VARCHAR(500) DEFAULT NULL COMMENT '证书附件URL',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`education_id`),
    INDEX `idx_employee` (`employee_id`),
    FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '员工教育经历表';

DROP TABLE IF EXISTS `employee_work_history`;
CREATE TABLE `employee_work_history` (
    `work_history_id` INT NOT NULL AUTO_INCREMENT COMMENT '工作经历ID',
    `employee_id` INT NOT NULL COMMENT '员工ID',
    `company_name` VARCHAR(100) NOT NULL COMMENT '曾任职公司',
    `position_name` VARCHAR(100) NOT NULL COMMENT '曾任职位',
    `start_date` DATE NOT NULL COMMENT '开始日期',
    `end_date` DATE DEFAULT NULL COMMENT '结束日期',
    `responsibilities` TEXT COMMENT '工作职责描述',
    `leaving_reason` VARCHAR(255) DEFAULT NULL COMMENT '离职原因',
    `certificate_contact` VARCHAR(100) DEFAULT NULL COMMENT '证明人及联系方式',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`work_history_id`),
    INDEX `idx_employee` (`employee_id`),
    FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '员工工作经历表';

DROP TABLE IF EXISTS `employee_contract`;
CREATE TABLE `employee_contract` (
    `contract_id` INT NOT NULL AUTO_INCREMENT COMMENT '合同ID',
    `employee_id` INT NOT NULL COMMENT '员工ID',
    `contract_no` VARCHAR(50) NOT NULL COMMENT '合同编号',
    `contract_type` ENUM('labor', 'service', 'internship', 'consultant', 'other') DEFAULT 'labor' COMMENT '合同类型',
    `contract_period` ENUM('fixed_term', 'open_term', 'project_based') DEFAULT 'fixed_term' COMMENT '合同期限',
    `start_date` DATE NOT NULL COMMENT '合同开始日期',
    `end_date` DATE DEFAULT NULL COMMENT '合同结束日期',
    `probation_months` TINYINT DEFAULT 0 COMMENT '试用期月数',
    `base_salary` DECIMAL(12, 2) NOT NULL COMMENT '合同基本工资',
    `salary_currency` CHAR(3) DEFAULT 'CNY' COMMENT '薪资币种',
    `work_location` VARCHAR(255) DEFAULT NULL COMMENT '工作地点',
    `working_hours` VARCHAR(50) DEFAULT NULL COMMENT '工时制度',
    `contract_file_url` VARCHAR(500) DEFAULT NULL COMMENT '合同扫描件URL',
    `sign_date` DATE DEFAULT NULL COMMENT '签订日期',
    `status` ENUM('draft', 'active', 'expired', 'terminated', 'renewed') DEFAULT 'active' COMMENT '合同状态',
    `termination_reason` VARCHAR(255) DEFAULT NULL COMMENT '终止/解除原因',
    `termination_date` DATE DEFAULT NULL COMMENT '实际终止日期',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`contract_id`),
    UNIQUE KEY `uk_contract_no` (`contract_no`),
    INDEX `idx_employee` (`employee_id`),
    INDEX `idx_status` (`status`),
    INDEX `idx_dates` (`start_date`, `end_date`),
    FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '员工合同表';

DROP TABLE IF EXISTS `attendance`;
CREATE TABLE `attendance` (
    `attendance_id` INT NOT NULL AUTO_INCREMENT COMMENT '考勤记录ID',
    `employee_id` INT NOT NULL COMMENT '员工ID',
    `attendance_date` DATE NOT NULL COMMENT '考勤日期',
    `check_in_time` TIME DEFAULT NULL COMMENT '上班打卡时间',
    `check_out_time` TIME DEFAULT NULL COMMENT '下班打卡时间',
    `check_in_device` VARCHAR(100) DEFAULT NULL COMMENT '打卡设备/方式',
    `check_out_device` VARCHAR(100) DEFAULT NULL COMMENT '签退设备/方式',
    `work_hours` DECIMAL(5, 2) DEFAULT NULL COMMENT '工作时长（小时）',
    `overtime_hours` DECIMAL(5, 2) DEFAULT 0.00 COMMENT '加班时长',
    `attendance_status` ENUM('present', 'late', 'early_leave', 'absent', 'business_trip', 'sick_leave', 'annual_leave', 'personal_leave', 'compensatory_leave', 'other_leave') DEFAULT 'present' COMMENT '考勤状态',
    `late_minutes` INT DEFAULT 0 COMMENT '迟到分钟数',
    `early_leave_minutes` INT DEFAULT 0 COMMENT '早退分钟数',
    `is_weekend` BOOLEAN DEFAULT FALSE COMMENT '是否周末',
    `is_holiday` BOOLEAN DEFAULT FALSE COMMENT '是否法定节假日',
    `remarks` VARCHAR(255) DEFAULT NULL COMMENT '备注',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`attendance_id`),
    UNIQUE KEY `uk_employee_date` (`employee_id`, `attendance_date`),
    INDEX `idx_date` (`attendance_date`),
    INDEX `idx_status` (`attendance_status`),
    FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '考勤表，记录每日员工打卡和出勤情况';

DROP TABLE IF EXISTS `leave_application`;
CREATE TABLE `leave_application` (
    `leave_id` INT NOT NULL AUTO_INCREMENT COMMENT '请假申请ID',
    `employee_id` INT NOT NULL COMMENT '申请人ID',
    `leave_type` ENUM('annual', 'sick', 'personal', 'marriage', 'maternity', 'paternity', 'bereavement', 'compensatory', 'other') NOT NULL COMMENT '请假类型',
    `start_date` DATE NOT NULL COMMENT '开始日期',
    `end_date` DATE NOT NULL COMMENT '结束日期',
    `start_time` ENUM('morning', 'afternoon', 'full_day') DEFAULT 'full_day' COMMENT '开始时间点',
    `end_time` ENUM('morning', 'afternoon', 'full_day') DEFAULT 'full_day' COMMENT '结束时间点',
    `total_days` DECIMAL(4, 1) NOT NULL COMMENT '请假总天数',
    `reason` TEXT NOT NULL COMMENT '请假事由',
    `attachment_urls` JSON DEFAULT NULL COMMENT '附件URL',
    `status` ENUM('pending', 'approved', 'rejected', 'cancelled') DEFAULT 'pending' COMMENT '审批状态',
    `approver_id` INT DEFAULT NULL COMMENT '审批人ID',
    `approval_time` TIMESTAMP NULL DEFAULT NULL COMMENT '审批时间',
    `approval_remark` VARCHAR(255) DEFAULT NULL COMMENT '审批意见',
    `applied_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '申请时间',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`leave_id`),
    INDEX `idx_employee` (`employee_id`),
    INDEX `idx_status` (`status`),
    INDEX `idx_date_range` (`start_date`, `end_date`),
    INDEX `idx_approver` (`approver_id`),
    FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`approver_id`) REFERENCES `employee` (`employee_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '请假申请表';

DROP TABLE IF EXISTS `overtime_application`;
CREATE TABLE `overtime_application` (
    `overtime_id` INT NOT NULL AUTO_INCREMENT COMMENT '加班申请ID',
    `employee_id` INT NOT NULL COMMENT '申请人ID',
    `overtime_date` DATE NOT NULL COMMENT '加班日期',
    `start_time` TIME NOT NULL COMMENT '开始时间',
    `end_time` TIME NOT NULL COMMENT '结束时间',
    `total_hours` DECIMAL(4, 1) NOT NULL COMMENT '加班总小时数',
    `overtime_type` ENUM('weekday', 'weekend', 'holiday') NOT NULL COMMENT '加班类型',
    `compensation_type` ENUM('overtime_pay', 'compensatory_leave') DEFAULT 'overtime_pay' COMMENT '补偿方式',
    `reason` VARCHAR(255) NOT NULL COMMENT '加班事由',
    `status` ENUM('pending', 'approved', 'rejected', 'cancelled') DEFAULT 'pending' COMMENT '审批状态',
    `approver_id` INT DEFAULT NULL COMMENT '审批人ID',
    `approval_time` TIMESTAMP NULL DEFAULT NULL COMMENT '审批时间',
    `approval_remark` VARCHAR(255) DEFAULT NULL COMMENT '审批意见',
    `applied_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '申请时间',
    PRIMARY KEY (`overtime_id`),
    INDEX `idx_employee` (`employee_id`),
    INDEX `idx_status` (`status`),
    INDEX `idx_date` (`overtime_date`),
    FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`approver_id`) REFERENCES `employee` (`employee_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '加班申请表';

DROP TABLE IF EXISTS `leave_balance`;
CREATE TABLE `leave_balance` (
    `balance_id` INT NOT NULL AUTO_INCREMENT COMMENT '余额ID',
    `employee_id` INT NOT NULL COMMENT '员工ID',
    `year` SMALLINT NOT NULL COMMENT '年份',
    `leave_type` ENUM('annual', 'sick', 'personal', 'other') NOT NULL COMMENT '假期类型',
    `total_days` DECIMAL(5, 1) NOT NULL COMMENT '年度总天数',
    `used_days` DECIMAL(5, 1) DEFAULT 0.00 COMMENT '已使用天数',
    `remaining_days` DECIMAL(5, 1) GENERATED ALWAYS AS (total_days - used_days) STORED COMMENT '剩余天数',
    `carried_over_days` DECIMAL(5, 1) DEFAULT 0.00 COMMENT '结转天数',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`balance_id`),
    UNIQUE KEY `uk_employee_year_type` (`employee_id`, `year`, `leave_type`),
    INDEX `idx_year` (`year`),
    FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '员工假期余额表';

DROP TABLE IF EXISTS `salary`;
CREATE TABLE `salary` (
    `salary_id` INT NOT NULL AUTO_INCREMENT COMMENT '薪资记录ID',
    `employee_id` INT NOT NULL COMMENT '员工ID',
    `salary_year` SMALLINT NOT NULL COMMENT '薪资年份',
    `salary_month` TINYINT NOT NULL COMMENT '薪资月份',
    `basic_salary` DECIMAL(12, 2) NOT NULL COMMENT '基本工资',
    `position_allowance` DECIMAL(10, 2) DEFAULT 0.00 COMMENT '岗位津贴',
    `transport_allowance` DECIMAL(10, 2) DEFAULT 0.00 COMMENT '交通补贴',
    `meal_allowance` DECIMAL(10, 2) DEFAULT 0.00 COMMENT '餐补',
    `housing_allowance` DECIMAL(10, 2) DEFAULT 0.00 COMMENT '住房补贴',
    `communication_allowance` DECIMAL(10, 2) DEFAULT 0.00 COMMENT '通讯补贴',
    `other_allowances` DECIMAL(10, 2) DEFAULT 0.00 COMMENT '其他补贴',
    `overtime_pay` DECIMAL(10, 2) DEFAULT 0.00 COMMENT '加班费',
    `commission` DECIMAL(12, 2) DEFAULT 0.00 COMMENT '提成',
    `bonus` DECIMAL(12, 2) DEFAULT 0.00 COMMENT '奖金',
    `total_income` DECIMAL(12, 2) GENERATED ALWAYS AS (
        basic_salary + position_allowance + transport_allowance + 
        meal_allowance + housing_allowance + communication_allowance + 
        other_allowances + overtime_pay + commission + bonus
    ) STORED COMMENT '应发合计',
    `social_security_employee` DECIMAL(10, 2) DEFAULT 0.00 COMMENT '社保个人缴纳',
    `social_security_company` DECIMAL(10, 2) DEFAULT 0.00 COMMENT '社保公司缴纳',
    `provident_fund_employee` DECIMAL(10, 2) DEFAULT 0.00 COMMENT '公积金个人缴纳',
    `provident_fund_company` DECIMAL(10, 2) DEFAULT 0.00 COMMENT '公积金公司缴纳',
    `income_tax` DECIMAL(10, 2) DEFAULT 0.00 COMMENT '个人所得税',
    `other_deductions` DECIMAL(10, 2) DEFAULT 0.00 COMMENT '其他扣款',
    `net_pay` DECIMAL(12, 2) GENERATED ALWAYS AS (
        total_income - social_security_employee - provident_fund_employee - income_tax - other_deductions
    ) STORED COMMENT '实发工资',
    `pay_date` DATE DEFAULT NULL COMMENT '实际发放日期',
    `payment_status` ENUM('pending', 'processing', 'paid', 'failed') DEFAULT 'pending' COMMENT '发放状态',
    `bank_transaction_id` VARCHAR(100) DEFAULT NULL COMMENT '银行交易流水号',
    `remark` VARCHAR(500) DEFAULT NULL COMMENT '备注',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`salary_id`),
    UNIQUE KEY `uk_employee_year_month` (`employee_id`, `salary_year`, `salary_month`),
    INDEX `idx_year_month` (`salary_year`, `salary_month`),
    INDEX `idx_payment_status` (`payment_status`),
    FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '薪资表，记录员工月度薪资明细';

DROP TABLE IF EXISTS `salary_adjustment`;
CREATE TABLE `salary_adjustment` (
    `adjustment_id` INT NOT NULL AUTO_INCREMENT COMMENT '调薪记录ID',
    `employee_id` INT NOT NULL COMMENT '员工ID',
    `adjustment_date` DATE NOT NULL COMMENT '调薪生效日期',
    `old_basic_salary` DECIMAL(12, 2) NOT NULL COMMENT '调薪前基本工资',
    `new_basic_salary` DECIMAL(12, 2) NOT NULL COMMENT '调薪后基本工资',
    `adjustment_amount` DECIMAL(12, 2) GENERATED ALWAYS AS (new_basic_salary - old_basic_salary) STORED COMMENT '调整金额',
    `adjustment_percentage` DECIMAL(5, 2) DEFAULT NULL COMMENT '调整百分比',
    `adjustment_reason` VARCHAR(255) NOT NULL COMMENT '调薪原因',
    `approver_id` INT DEFAULT NULL COMMENT '审批人ID',
    `approved_at` TIMESTAMP NULL DEFAULT NULL COMMENT '审批时间',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`adjustment_id`),
    INDEX `idx_employee` (`employee_id`),
    INDEX `idx_date` (`adjustment_date`),
    FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`approver_id`) REFERENCES `employee` (`employee_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '薪资调整记录表';

DROP TABLE IF EXISTS `performance_review`;
CREATE TABLE `performance_review` (
    `review_id` INT NOT NULL AUTO_INCREMENT COMMENT '评估ID',
    `employee_id` INT NOT NULL COMMENT '被评估员工ID',
    `reviewer_id` INT NOT NULL COMMENT '评估人ID',
    `review_period_start` DATE NOT NULL COMMENT '评估周期开始',
    `review_period_end` DATE NOT NULL COMMENT '评估周期结束',
    `review_type` ENUM('quarterly', 'semi_annual', 'annual', 'project') DEFAULT 'annual' COMMENT '评估类型',
    `overall_score` DECIMAL(3, 1) CHECK (overall_score BETWEEN 0 AND 10) COMMENT '综合评分',
    `performance_grade` ENUM('excellent', 'good', 'average', 'below_average', 'poor') DEFAULT NULL COMMENT '绩效等级',
    `self_assessment` TEXT COMMENT '自评内容',
    `manager_assessment` TEXT COMMENT '上级评价',
    `strengths` TEXT COMMENT '优点',
    `improvements` TEXT COMMENT '待改进项',
    `goals_achieved` TEXT COMMENT '目标完成情况',
    `goals_next_period` TEXT COMMENT '下阶段目标',
    `training_needs` TEXT COMMENT '培训需求',
    `recommendation` ENUM('promote', 'bonus', 'training', 'warning', 'termination') DEFAULT NULL COMMENT '建议措施',
    `status` ENUM('draft', 'submitted', 'in_review', 'completed', 'cancelled') DEFAULT 'draft' COMMENT '评估状态',
    `submitted_at` TIMESTAMP NULL DEFAULT NULL COMMENT '提交时间',
    `completed_at` TIMESTAMP NULL DEFAULT NULL COMMENT '完成时间',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`review_id`),
    INDEX `idx_employee` (`employee_id`),
    INDEX `idx_reviewer` (`reviewer_id`),
    INDEX `idx_period` (`review_period_start`, `review_period_end`),
    INDEX `idx_grade` (`performance_grade`),
    FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`reviewer_id`) REFERENCES `employee` (`employee_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '绩效评估表';

DROP TABLE IF EXISTS `training`;
CREATE TABLE `training` (
    `training_id` INT NOT NULL AUTO_INCREMENT COMMENT '培训ID',
    `employee_id` INT NOT NULL COMMENT '参训员工ID',
    `training_name` VARCHAR(200) NOT NULL COMMENT '培训名称',
    `training_type` ENUM('onboarding', 'technical', 'soft_skill', 'management', 'compliance', 'safety', 'other') DEFAULT NULL COMMENT '培训类型',
    `provider` VARCHAR(100) DEFAULT NULL COMMENT '培训提供方',
    `start_date` DATE NOT NULL COMMENT '开始日期',
    `end_date` DATE DEFAULT NULL COMMENT '结束日期',
    `duration_hours` DECIMAL(5, 1) DEFAULT NULL COMMENT '培训时长',
    `location` VARCHAR(255) DEFAULT NULL COMMENT '培训地点',
    `certificate_obtained` BOOLEAN DEFAULT FALSE COMMENT '是否获得证书',
    `certificate_url` VARCHAR(500) DEFAULT NULL COMMENT '证书附件URL',
    `score` DECIMAL(5, 2) DEFAULT NULL COMMENT '考核分数',
    `cost` DECIMAL(10, 2) DEFAULT NULL COMMENT '培训费用',
    `cost_currency` CHAR(3) DEFAULT 'CNY' COMMENT '费用币种',
    `remarks` VARCHAR(500) DEFAULT NULL COMMENT '备注',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`training_id`),
    INDEX `idx_employee` (`employee_id`),
    INDEX `idx_type` (`training_type`),
    INDEX `idx_date` (`start_date`),
    FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '员工培训记录表';

DROP TABLE IF EXISTS `reward_discipline`;
CREATE TABLE `reward_discipline` (
    `record_id` INT NOT NULL AUTO_INCREMENT COMMENT '记录ID',
    `employee_id` INT NOT NULL COMMENT '员工ID',
    `record_type` ENUM('reward', 'discipline') NOT NULL COMMENT '记录类型：奖励/惩处',
    `category` VARCHAR(50) NOT NULL COMMENT '类别',
    `record_date` DATE NOT NULL COMMENT '发生日期',
    `amount` DECIMAL(10, 2) DEFAULT NULL COMMENT '金额',
    `reason` TEXT NOT NULL COMMENT '原因/事由',
    `issuer_id` INT DEFAULT NULL COMMENT '颁发/处理人ID',
    `document_url` VARCHAR(500) DEFAULT NULL COMMENT '证明文件URL',
    `status` ENUM('active', 'rescinded', 'expired') DEFAULT 'active' COMMENT '状态',
    `rescinded_reason` VARCHAR(255) DEFAULT NULL COMMENT '撤销原因',
    `rescinded_at` TIMESTAMP NULL DEFAULT NULL COMMENT '撤销时间',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`record_id`),
    INDEX `idx_employee` (`employee_id`),
    INDEX `idx_type` (`record_type`),
    INDEX `idx_date` (`record_date`),
    FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`issuer_id`) REFERENCES `employee` (`employee_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '员工奖惩记录表';

DROP TABLE IF EXISTS `employee_transfer`;
CREATE TABLE `employee_transfer` (
    `transfer_id` INT NOT NULL AUTO_INCREMENT COMMENT '调动记录ID',
    `employee_id` INT NOT NULL COMMENT '员工ID',
    `transfer_date` DATE NOT NULL COMMENT '调动生效日期',
    `from_dept_id` INT DEFAULT NULL COMMENT '调出部门ID',
    `to_dept_id` INT DEFAULT NULL COMMENT '调入部门ID',
    `from_position_id` INT DEFAULT NULL COMMENT '调出岗位ID',
    `to_position_id` INT DEFAULT NULL COMMENT '调入岗位ID',
    `from_supervisor_id` INT DEFAULT NULL COMMENT '调出前直属上级',
    `to_supervisor_id` INT DEFAULT NULL COMMENT '调入后直属上级',
    `transfer_type` ENUM('promotion', 'demotion', 'transfer', 'secondment', 'rotation') NOT NULL COMMENT '调动类型',
    `transfer_reason` VARCHAR(255) DEFAULT NULL COMMENT '调动原因',
    `approver_id` INT DEFAULT NULL COMMENT '审批人ID',
    `approved_at` TIMESTAMP NULL DEFAULT NULL COMMENT '审批时间',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`transfer_id`),
    INDEX `idx_employee` (`employee_id`),
    INDEX `idx_date` (`transfer_date`),
    INDEX `idx_type` (`transfer_type`),
    FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`from_dept_id`) REFERENCES `department` (`dept_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (`to_dept_id`) REFERENCES `department` (`dept_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (`from_position_id`) REFERENCES `position` (`position_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (`to_position_id`) REFERENCES `position` (`position_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (`approver_id`) REFERENCES `employee` (`employee_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '员工调动记录表';


INSERT INTO `company` (`company_code`, `company_name`, `short_name`, `legal_representative`, `status`, `founding_date`) VALUES
('COM001', '云创科技有限公司', '云创科技', '张伟', 'active', '2015-06-01'),
('COM002', '智汇信息技术有限公司', '智汇信息', '李娜', 'active', '2018-03-15');

INSERT INTO `department` (`company_id`, `parent_dept_id`, `dept_code`, `dept_name`, `sort_order`, `status`) VALUES
(1, NULL, 'DEPT001', '技术部', 1, 'active'),
(1, NULL, 'DEPT002', '产品部', 2, 'active'),
(1, NULL, 'DEPT003', '销售部', 3, 'active'),
(1, NULL, 'DEPT004', '人力资源部', 4, 'active'),
(1, 1, 'DEPT001-01', '后端开发组', 1, 'active'),
(1, 1, 'DEPT001-02', '前端开发组', 2, 'active'),
(2, NULL, 'DEPT005', '研发中心', 1, 'active');

INSERT INTO `position` (`company_id`, `position_code`, `position_name`, `position_level`, `min_salary`, `max_salary`, `status`) VALUES
(1, 'POS001', '技术总监', 'director', 40000.00, 60000.00, 'active'),
(1, 'POS002', '高级工程师', 'senior', 25000.00, 35000.00, 'active'),
(1, 'POS003', '中级工程师', 'middle', 15000.00, 25000.00, 'active'),
(1, 'POS004', '初级工程师', 'junior', 8000.00, 15000.00, 'active'),
(1, 'POS005', '产品经理', 'manager', 20000.00, 35000.00, 'active'),
(1, 'POS006', '销售经理', 'manager', 15000.00, 30000.00, 'active'),
(1, 'POS007', 'HRBP', 'middle', 12000.00, 20000.00, 'active'),
(2, 'POS008', '技术专家', 'senior', 30000.00, 45000.00, 'active');

INSERT INTO `employee` (
    `employee_no`, `company_id`, `dept_id`, `position_id`, `id_card_number`, `full_name`, 
    `gender`, `phone`, `work_email`, `hire_date`, `employment_status`, `supervisor_id`
) VALUES
('EMP001', 1, 1, 1, '110101199001011234', '张伟', 'male', '13800000001', 'zhang.wei@yunchuang.com', '2015-06-01', 'active', NULL),
('EMP002', 1, 1, 2, '110101199102021235', '李明', 'male', '13800000002', 'li.ming@yunchuang.com', '2016-03-15', 'active', 1),
('EMP003', 1, 2, 2, '110101199203031236', '王芳', 'female', '13800000003', 'wang.fang@yunchuang.com', '2017-08-20', 'active', 1),
('EMP004', 1, 3, 6, '110101199304041237', '赵强', 'male', '13800000004', 'zhao.qiang@yunchuang.com', '2018-01-10', 'active', 1),
('EMP005', 1, 1, 3, '110101199405051238', '陈丽', 'female', '13800000005', 'chen.li@yunchuang.com', '2019-04-01', 'active', 2),
('EMP006', 1, 1, 3, '110101199506061239', '刘洋', 'male', '13800000006', 'liu.yang@yunchuang.com', '2020-07-15', 'active', 2),
('EMP007', 1, 4, 7, '110101199607071240', '孙梅', 'female', '13800000007', 'sun.mei@yunchuang.com', '2021-02-20', 'probation', 1),
('EMP008', 2, 5, 8, '110101199708081241', '周涛', 'male', '13800000008', 'zhou.tao@zhihui.com', '2019-09-01', 'active', NULL);

UPDATE `department` SET `dept_leader_id` = 1 WHERE `dept_id` = 1;
UPDATE `department` SET `dept_leader_id` = 2 WHERE `dept_id` = 2;
UPDATE `department` SET `dept_leader_id` = 4 WHERE `dept_id` = 3;
UPDATE `department` SET `dept_leader_id` = 7 WHERE `dept_id` = 4;

INSERT INTO `performance_review` (`employee_id`, `reviewer_id`, `review_period_start`, `review_period_end`, `review_type`, `overall_score`, `performance_grade`, `status`) VALUES
(1, 1, '2024-01-01', '2024-12-31', 'annual', 9.5, 'excellent', 'completed'),
(2, 1, '2024-01-01', '2024-12-31', 'annual', 8.5, 'good', 'completed'),
(3, 1, '2024-01-01', '2024-12-31', 'annual', 8.0, 'good', 'completed'),
(4, 1, '2024-01-01', '2024-12-31', 'annual', 7.5, 'average', 'completed'),
(5, 2, '2024-01-01', '2024-12-31', 'annual', 8.5, 'good', 'completed'),
(6, 2, '2024-01-01', '2024-12-31', 'annual', 7.0, 'average', 'completed');

INSERT INTO `salary` (`employee_id`, `salary_year`, `salary_month`, `basic_salary`, `position_allowance`, `transport_allowance`, `meal_allowance`, `housing_allowance`, `overtime_pay`, `commission`, `bonus`, `social_security_employee`, `provident_fund_employee`, `income_tax`, `pay_date`, `payment_status`) VALUES
(1, 2024, 1, 45000.00, 5000.00, 1000.00, 500.00, 3000.00, 0.00, 0.00, 50000.00, 5000.00, 3000.00, 15000.00, '2024-01-31', 'paid'),
(2, 2024, 1, 28000.00, 3000.00, 1000.00, 500.00, 2000.00, 2000.00, 0.00, 10000.00, 3500.00, 2000.00, 6000.00, '2024-01-31', 'paid'),
(3, 2024, 1, 26000.00, 3000.00, 1000.00, 500.00, 2000.00, 1000.00, 5000.00, 8000.00, 3200.00, 2000.00, 5000.00, '2024-01-31', 'paid'),
(4, 2024, 1, 22000.00, 2000.00, 1000.00, 500.00, 2000.00, 3000.00, 20000.00, 15000.00, 2800.00, 2000.00, 8000.00, '2024-01-31', 'paid'),
(5, 2024, 1, 18000.00, 2000.00, 800.00, 500.00, 1500.00, 1000.00, 0.00, 3000.00, 2200.00, 1500.00, 2500.00, '2024-01-31', 'paid'),
(6, 2024, 1, 16000.00, 1500.00, 800.00, 500.00, 1500.00, 2000.00, 0.00, 2000.00, 2000.00, 1500.00, 2000.00, '2024-01-31', 'paid');

INSERT INTO `attendance` (`employee_id`, `attendance_date`, `check_in_time`, `check_out_time`, `work_hours`, `attendance_status`) VALUES
(1, '2024-01-02', '09:00:00', '18:00:00', 8.00, 'present'),
(1, '2024-01-03', '09:00:00', '18:00:00', 8.00, 'present'),
(1, '2024-01-04', '09:15:00', '18:00:00', 7.75, 'late'),
(2, '2024-01-02', '09:00:00', '18:00:00', 8.00, 'present'),
(2, '2024-01-03', '09:00:00', '19:00:00', 9.00, 'present'),
(3, '2024-01-02', '09:00:00', '18:00:00', 8.00, 'present'),
(3, '2024-01-04', NULL, NULL, 0.00, 'annual_leave');

SELECT '数据库创建完成！' AS message;
SELECT COUNT(*) AS company_count FROM company;
SELECT COUNT(*) AS department_count FROM department;
SELECT COUNT(*) AS position_count FROM position;
SELECT COUNT(*) AS employee_count FROM employee;
SELECT COUNT(*) AS salary_count FROM salary;