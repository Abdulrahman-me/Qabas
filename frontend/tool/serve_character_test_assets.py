"""Serve development companion, content and private grading fixtures for Chrome tests."""
import http.server
from functools import partial
from pathlib import Path


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith('/mock_fixture/'):
            path = self.path.removeprefix('/mock_fixture/')
            allowed = {
                'examples/INDEX.json',
                'examples/User__5_1_user__0.json',
                'examples/Stats__get_me_stats__0.json',
                'examples/Achievements__get_me_achievements__0.json',
                'examples/Quests__get_me_quests__0.json',
                'examples/League__get_leagues_current__0.json',
                'examples/Page_Friend__get_friends__0.json',
                'examples/Invite__post_friends_invites_201__0.json',
                'examples/Duel__duel_object__0.json',
                'examples/Session__post_sessions__4.json',
                'examples/Page_Invitation__get_duels_invitations__0.json',
                'examples/Page_TermCard__get_glossary_state_all_new_learning_mastered_cur__0.json',
                'examples/AssistantFailed__get_raqeeb_messages_message_id__1.json',
                *{f'examples/RaqeebCompleted__get_raqeeb_messages_message_id__{i}.json' for i in range(3, 11)},
                'examples/Evidence__5_3_evidence__0.json',
                'examples/Evidence__5_3_evidence__1.json',
                'examples/Guide__get_units_unit_id_guide__0.json',
                'examples/TermCard__5_4_termcard__0.json',
                'demo_curriculum/curriculum.json',
                'examples/AuthResp__post_auth_reviewer__1.json',
                'examples/FactoryRun__get_admin_factory_runs_run_id_factoryrun__0.json',
                'examples/DraftFragment__gate_2_draft_status_awaiting_gate2__0.json',
                'examples/BlindPair__get_admin_blind_test_next__0.json',
                'examples/Metrics__get_admin_metrics__0.json',
            }
            if '..' in path or path.startswith('/'):
                self.send_error(404)
                return
            if path not in allowed and not path.startswith(('recording/', 'salah/', 'test_lessons/', 'unit0/sessions/', 'private/salah_keys_', 'private/unit0/', 'private/test_lessons/', 'contract/', 'reviewer/')) and path not in {'unit0/SESSION_INDEX.json', 'unit0/DRAFT_NOTICES.json', 'unit0/MEDIA_INDEX.json'}:
                self.send_error(404)
                return
            data = (Path(__file__).resolve().parents[1] / 'assets/mocks' / path).read_bytes()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        if self.path.startswith('/mock_media/'):
            path = self.path.removeprefix('/mock_media/')
            if '..' in path or not path.startswith(('unit0/media/fallbacks/', 'unit0/media/scenes/', 'contract/mock_assets/')):
                self.send_error(404)
                return
            data = (Path(__file__).resolve().parents[1] / 'assets/mocks' / path).read_bytes()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json' if path.endswith('.json') else 'image/webp' if path.endswith('.webp') else 'image/svg+xml')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        super().do_GET()

    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

    def log_message(self, *args):
        pass


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1] / 'assets' / 'characters'
    http.server.ThreadingHTTPServer(
        ('127.0.0.1', 8284), partial(Handler, directory=str(root))
    ).serve_forever()
