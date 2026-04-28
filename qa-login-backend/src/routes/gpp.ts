import { Router, Request, Response } from 'express';

const router = Router();

let gppEntries: any[] = [];

router.get('/', (req: Request, res: Response) => {
  const { search } = req.query;
  let result = gppEntries;

  if (search && typeof search === 'string') {
    const q = search.toLowerCase();
    result = gppEntries.filter(
      (e) =>
        e.doelstellingMaatregel?.toLowerCase().includes(q) ||
        e.domein?.toLowerCase().includes(q)
    );
  }

  res.json({ entries: result });
});

router.post('/', (req: Request, res: Response) => {
  const entry = {
    id: Date.now(),
    jaar: new Date().getFullYear(),
    ...req.body,
  };
  gppEntries.push(entry);
  res.status(201).json({ entry });
});

router.patch('/:id', (req: Request, res: Response) => {
  const id = parseInt(req.params.id);
  const index = gppEntries.findIndex((e) => e.id === id);
  if (index === -1) return res.status(404).json({ message: 'Entry niet gevonden' });
  gppEntries[index] = { ...gppEntries[index], ...req.body };
  res.json({ entry: gppEntries[index] });
});

router.delete('/:id', (req: Request, res: Response) => {
  const id = parseInt(req.params.id);
  gppEntries = gppEntries.filter((e) => e.id !== id);
  res.status(204).send();
});

export default router;