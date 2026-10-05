class MediaError(Exception):
    """Safe diagnostics without URLs, credentials or raw provider responses."""


class MediaNotConfigured(MediaError):
    pass


class MediaUnavailable(MediaError):
    pass


class MediaRefused(MediaError):
    pass


class MediaInvalid(MediaError):
    pass
