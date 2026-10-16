-- ================================================
-- 学习笔记
-- ================================================

-- 查mysql保留字(reserved = 1 就是不能用) ---------
select word, reserved from information_schema.keywords where word = '名称'; 