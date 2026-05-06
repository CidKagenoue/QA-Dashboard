export type JapStoreEntry = {
  id: number;
  jaar: number;
  doelstellingMaatregel?: string;
  domein?: string;
  risicoveld?: string;
  prioriteit?: string;
  realisatie?: string;
  uitvoerder?: string;
  middelenBudgetWerkuren?: string;
  startdatum?: string;
  einddatum?: string;
  opmerking?: string;
  generatedFromGppId?: number;
  [key: string]: any;
};

export type GppStoreEntry = {
  id: number;
  startJaar: number;
  eindJaar: number;
  doelstellingMaatregel?: string;
  domein?: string;
  risicoveld?: string;
  prioriteit?: string;
  realisatie?: string;
  uitvoerder?: string;
  middelenBudgetWerkuren?: string;
  startdatum?: string;
  einddatum?: string;
  opmerking?: string;
  [key: string]: any;
};

export const store = {
  japEntries: [] as JapStoreEntry[],
  gppEntries: [] as GppStoreEntry[],
};
