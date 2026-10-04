"""Reference algorithm for fresh-device lesson recovery (contract §6.5.5). Executable spec + used by tests.

Inputs: the served session items (top-level, authored order) and the learner-visible answer history
(`Session.answers`, oldest first). Output: where to resume, which retries remain, and the stage.

Rules (rev 6):
  * Cursor: first attempts only, in AUTHORED order. Resume after the longest contiguous answered prefix
    of exercise blocks (a gap — a later exercise answered while an earlier one isn't — resumes at the
    content boundary before the earliest unanswered exercise; the server also rejects out-of-order
    first attempts, so gaps should not occur).
  * Retries never move the cursor.
  * One retry per exercise: an exercise leaves the retry queue once ANY retry is recorded for it,
    correct or not. Recitation, flashcards, and neutral/hidden outcomes never enter the queue.
  * Content reading is not recorded server-side: recovery is conservative and re-shows content after
    the resume point.
"""
NO_RETRY = {"recite_verse", "flashcard"}


def resume_point(items, answers):
    ex_pos = [(i, b["exercise"]["exercise_id"], b["exercise"]["type"]) for i, b in enumerate(items) if b["type"] == "exercise"]
    known = {e for _, e, _ in ex_pos}
    first, retried = {}, set()
    for a in answers:
        if a["exercise_id"] not in known:
            raise ValueError("answer for an exercise not served in this session")
        if a["is_retry"]:
            retried.add(a["exercise_id"])
        else:
            first.setdefault(a["exercise_id"], a)
    # contiguous answered prefix in authored order
    prefix_end = -1          # item index of the last exercise in the contiguous prefix
    first_gap = None         # item index of the earliest unanswered exercise
    for i, e, _ in ex_pos:
        if e in first:
            if first_gap is None:
                prefix_end = i
        elif first_gap is None:
            first_gap = i
    queue = [e for i, e, t in ex_pos
             if e in first and first[e]["result"] == "incorrect" and t not in NO_RETRY and e not in retried]
    if first_gap is not None:
        return {"stage": "steps", "next_item_index": prefix_end + 1, "retry_queue": queue, "gap": any(e in first for i, e, _ in ex_pos if i > first_gap)}
    trailing = [i for i in range(prefix_end + 1, len(items)) if items[i]["type"] != "exercise"]
    if trailing:
        return {"stage": "steps", "next_item_index": trailing[0], "retry_queue": queue, "gap": False}
    return {"stage": "retries" if queue else "completion", "next_item_index": None, "retry_queue": queue, "gap": False}
