"""Synthetic regression cases for the approved Taiwan glossary (spec 094)."""
import importlib.util
import json
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / 'generate-zh-hant.py'
SPEC = importlib.util.spec_from_file_location('zh_hant_generator', SCRIPT)
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)


class TaiwanVocabularyTests(unittest.TestCase):
    def test_publish_and_get_code_use_v22_vocabulary(self):
        cases = (
            ('CoachKit', 'coach.import.publishToStudent', '发布给学员', '發布給學員'),
            ('CoachKit', 'coach.planning.step7.publishToStudent', '发布给学员', '發布給學員'),
            ('AppShell', 'auth.getCode', '获取验证码', '取得驗證碼'),
        )
        for module, key, source, expected in cases:
            with self.subTest(key=key):
                self.assertEqual(generator.translate(source, key=key), expected)
                path = generator.ROOT / f'Modules/{module}/Sources/{module}/Resources/Localizable.xcstrings'
                entry = json.loads(path.read_text())['strings'][key]['localizations']
                self.assertEqual(entry['zh-Hant']['stringUnit']['value'], expected)

    def test_plan_and_feedback_compounds(self):
        self.assertEqual(generator.translate('发布训练计划并提交视频反馈'), '發布課表並提交影片反饋')
        self.assertEqual(generator.translate('计划编辑器'), '課表編輯器')

    def test_rep_context_is_explicit(self):
        self.assertEqual(generator.translate('次数', key='designSystem.reps'), '下數')
        self.assertEqual(generator.translate('%lld 次', key='coach.planning.count.rep %lld'), '%lld 下')
        self.assertEqual(generator.translate('每周 %lld 次', key='coach.profile.weeklyFrequency %lld'), '每週 %lld 次')
        self.assertEqual(generator.translate('第3次训练，次日再试'), '第3次訓練，次日再試')
        self.assertEqual(generator.translate('第 {0} 组填入上次数值', key='student.accessory.useLast'), '第 {0} 組填入上次數值')

    def test_equipment_bar_and_lever_remain_distinct(self):
        self.assertEqual(generator.translate('EZ杆二头弯举'), 'EZ槓二頭彎舉')
        self.assertEqual(generator.translate('坐姿杠杆臂屈伸'), '坐姿槓桿臂屈伸')

    def test_generated_rep_and_retry_labels(self):
        def label(module, key):
            path = generator.ROOT / f'Modules/{module}/Sources/{module}/Resources/Localizable.xcstrings'
            return json.loads(path.read_text())['strings'][key]['localizations']['zh-Hant']['stringUnit']['value']
        self.assertEqual(label('DesignSystem', 'designSystem.reps'), '下數')
        self.assertIn('嘗試次數', label('AppShell', 'auth.rateLimited'))
        self.assertIn('上次數值', label('StudentKit', 'student.accessory.useLast'))


if __name__ == '__main__':
    unittest.main()
