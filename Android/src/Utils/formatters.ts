export function formatDistance(meters: number, fractionDigits = 1): string {
  return `${(meters / 1000).toFixed(fractionDigits)} км`;
}

export function formatDuration(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds < 0) return '—';
  const total = Math.round(seconds);
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const remainingSeconds = total % 60;
  if (hours > 0) {
    return `${hours}:${String(minutes).padStart(2, '0')}:${String(remainingSeconds).padStart(2, '0')}`;
  }
  return `${minutes}:${String(remainingSeconds).padStart(2, '0')}`;
}

export function formatPace(secondsPerKilometer: number): string {
  return `${formatDuration(secondsPerKilometer)} /км`;
}

export function sportName(type: string): string {
  const normalized = type.toLowerCase();
  if (normalized.includes('run')) return 'Бег';
  if (normalized.includes('ride') || normalized.includes('cycl')) return 'Велосипед';
  if (normalized.includes('swim')) return 'Плавание';
  if (normalized.includes('walk')) return 'Ходьба';
  if (normalized.includes('hike')) return 'Поход';
  return type;
}

export function isRunning(type: string): boolean {
  return type.toLowerCase().includes('run');
}
