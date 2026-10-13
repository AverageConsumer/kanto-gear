import unittest
from tools.performance_report import parse
from tools.phone_profile import parse_sample, proc_stat


class PhoneProfilingTest(unittest.TestCase):
    def test_stream_events_survive_without_report_window(self):
        text = ('KGPROF v=1 kind=stutter id=2 interval=400.000 source=33.000\n'
                'KGPROF v=1 kind=browser_stop reason=contact_timeout received=1600.000\n'
                'KGPROF v=1 kind=disconnect reason=peer_closed browser=contact_timeout\n')
        run = parse(text)[0]
        self.assertEqual([event['kind'] for event in run['events']], ['stutter', 'browser_stop', 'disconnect'])
        self.assertEqual(run['windows'], [])

    def test_counters_and_truncated_reports(self):
        header = 'KGPROF v=1 seq=1 kind=window at=1 seconds=10 frames=2 bytes=32 context=phone mixed=false metrics=0 counters=1\n'
        counter = 'KGPROF v=1 seq=1 kind=counter name=phone_wire_bytes value=15\n'
        end = 'KGPROF v=1 seq=1 kind=end\n'
        self.assertFalse(parse(header + end)[0]['windows'][0]['complete'])
        window = parse(header + counter + end)[0]['windows'][0]
        self.assertTrue(window['complete'])
        self.assertEqual(window['counters']['phone_wire_bytes'], 15)
        self.assertTrue(parse(header.replace(' counters=1', '') + end)[0]['windows'][0]['complete'])

    def test_stat_names_and_battery_units(self):
        fields = ['S'] + ['0'] * 20
        fields[11], fields[12], fields[19] = '120', '30', '999'
        text = '42 (worker (video)) ' + ' '.join(fields)
        self.assertEqual(proc_stat(text), {'id': 42, 'name': 'worker (video)', 'ticks': 150, 'start': 999})
        raw = ('uptime 10.5 9.0\nprocess ' + text
               + '\n/sys/class/power_supply/battery/current_now -1000000'
               + '\n/sys/class/power_supply/battery/voltage_now 4000000'
               + '\n/sys/class/power_supply/battery/status Discharging\n')
        self.assertEqual(parse_sample(raw)['battery_discharge_w'], 4)
        self.assertNotIn('battery_discharge_w', parse_sample(raw.replace('Discharging', 'Charging')))


if __name__ == '__main__':
    unittest.main()
