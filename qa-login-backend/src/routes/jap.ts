import { Router, Request, Response } from 'express';

const router = Router();

// Tijdelijke in-memory opslag (later vervangen door database)
let japEntries: any[] = [];

// GET /jap - haal alle entries op
router.get('/', (req: Request, res: Response) => {
  const { search } = req.query;

  let result = japEntries;

  if (search && typeof search === 'string') {
    const q = search.toLowerCase();
    result = japEntries.filter(
      (e) =>
        e.doelstellingMaatregel?.toLowerCase().includes(q) ||
        e.domein?.toLowerCase().includes(q)
    );
  }

  res.json({ entries: result });
});

// POST /jap - maak nieuwe entry aan
router.post('/', (req: Request, res: Response) => {
  const entry = { 
    id: Date.now(),  
    jaar: new Date().getFullYear(),
    ...req.body,
  };
  japEntries.push(entry);
  res.status(201).json({ entry });
});

// PATCH /jap/:id - update een entry
router.patch('/:id', (req: Request, res: Response) => {
  const id = parseInt(req.params.id);
  const index = japEntries.findIndex((e) => e.id === id);

  if (index === -1) {
    return res.status(404).json({ message: 'Entry niet gevonden' });
  }

  japEntries[index] = { ...japEntries[index], ...req.body };
  res.json({ entry: japEntries[index] });
});

// DELETE /jap/:id - verwijder een entry
router.delete('/:id', (req: Request, res: Response) => {
  const id = parseInt(req.params.id);
  japEntries = japEntries.filter((e) => e.id !== id);
  res.status(204).send();
});

export default router;