/// URLs del CDN público de la NBA (GDD §9). Sin API key ni autenticación.
abstract final class NbaCdn {
  static String headshot(int nbaPlayerId) => 'https://cdn.nba.com/headshots/nba/latest/1040x760/$nbaPlayerId.png';

  static String logo(int nbaTeamId) => 'https://cdn.nba.com/logos/nba/$nbaTeamId/primary/L/logo.svg';
}
