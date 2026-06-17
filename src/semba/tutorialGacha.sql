
DELETE FROM gachas;
INSERT INTO gachas
(gachaId, gachaCategoryId, guaranteedCount, isGuaranteedPickup, executionCount, isSelectable)
VALUES

(101, 4, 0, 'false', 0, 'true')
;

DELETE FROM gachaButtonStates;
INSERT INTO gachaButtonStates (gachaId, gachaButtonId, executionCount, lastExecutedAt) VALUES
(101, 5, 0, '')
;

DELETE FROM gachaRates;
INSERT INTO gachaRates (gachaRateId, gachaRateSetId, percentRate) VALUES
(10101, 10100, '100.000')
,(10103, 10101, '100.000')
,(10102, 10102, '100.000')
;

DELETE FROM gachaCards;
INSERT INTO gachaCards (cardType, cardId, isAttention, isSelectable, gachaCardId, gachaRateId) VALUES
(4, 100501, 'false', 'false', 101001, 10101)
,(4, 100301, 'true', 'true', 1099, 10103)
,(4, 100401, 'true', 'true', 1100, 10103)
,(4, 101101, 'true', 'true', 1101, 10103)
,(4, 101301, 'true', 'true', 1102, 10103)
,(4, 100301, 'true', 'true', 1099, 10102)
,(4, 100401, 'true', 'true', 1100, 10102)
,(4, 101101, 'true', 'true', 1101, 10102)
,(4, 101301, 'true', 'true', 1102, 10102)
;
