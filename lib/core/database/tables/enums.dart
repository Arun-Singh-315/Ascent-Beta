// Shared enums for the Ascent database layer.
// Import this file wherever enum types are needed.

enum PacingRule {
  fixedInterval,
  evenlyByEndDate,
  manualPerItem,
}

enum SeriesComputedStatus {
  onTrack,
  atRisk,
  recovering,
  completed,
}

enum TaskPriority {
  low,
  medium,
  high,
}

enum ApplicationStage {
  wishlist,
  applied,
  oaScreen,
  interview,
  offer,
  rejected,
}

enum DsaDifficulty {
  easy,
  medium,
  hard,
}

enum DsaTopic {
  arrays,
  strings,
  linkedLists,
  trees,
  graphs,
  dynamicProgramming,
  greedy,
  backtracking,
  binarySearch,
  stacksQueues,
  heaps,
  tries,
  sorting,
  math,
  bitManipulation,
  other,
}
