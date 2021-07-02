select in_log('trans_amor.sql', 'Penambahan table trans_amor. Merupakan table transaksi untukk amor_etap.');

CREATE TABLE public.trans_amor
(
    id_xa serial NOT NULL,
    id_ae integer NOT NULL,
    id_djr integer NOT NULL,
    CONSTRAINT xa_key PRIMARY KEY (id_xa),
    CONSTRAINT xa_ae FOREIGN KEY (id_ae)
        REFERENCES public.amor_etap (id_ae) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE
        NOT VALID,
    CONSTRAINT xa_djr FOREIGN KEY (id_djr)
        REFERENCES public.jurnal_detil (id_djr) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE
        NOT VALID
)
WITH (
    OIDS = FALSE
);

COMMENT ON TABLE public.trans_amor
    IS 'Transaksi amortisasi';


