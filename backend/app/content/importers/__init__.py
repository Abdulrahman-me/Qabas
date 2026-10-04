"""Converters from upstream authoring formats into gold lessons (factory §13.7, SEED_AND_IMPORT).

A converter never guesses: anything that needs a human, a verified source or published media becomes a
:class:`~app.content.importers.report.Blocker`, and a lesson with blockers produces no gold file.
"""
