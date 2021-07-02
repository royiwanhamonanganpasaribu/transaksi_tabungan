select in_log('amor_test.sql', 'Create function string2Id_krd, generate_trans_amor. Delete seluruh isi tabel trans_amor, dan isi dengan data dari jurnal detil untuk COA: 130.11, 130.12, 130.21, 130.22, 130.31, 130.32. Sebelum menjalankan script ini, table trans_amor harus sudah ada (ada di script trans_amor.sql).');

CREATE OR REPLACE FUNCTION public.string2id_krd(IN st character varying,IN header character varying,IN fr integer,IN lg integer,IN prefix character varying)
    RETURNS integer
    LANGUAGE 'plpgsql'
    VOLATILE
    PARALLEL UNSAFE
    COST 100
AS $BODY$declare
  hasil integer;
  posisi integer;
  akta text;

begin
  posisi = position(header in st);
  akta = prefix || substring(st from posisi+fr for lg);
  select id_krd into hasil from kredit where akta_krd = akta;
  return hasil;
end;$BODY$;

CREATE OR REPLACE FUNCTION public.generate_trans_amor(IN coa integer)
    RETURNS integer
    LANGUAGE 'plpgsql'
    VOLATILE
    PARALLEL UNSAFE
    COST 100
AS $BODY$declare
  hasil integer;
  djr record;
  amortype text;
  krd integer;
  ae integer;
  depan text;
  depan2 text;

begin
  hasil := 0;
  for djr in  select id_djr, ket_djr from jurnal_detil where id_coa = coa
    --limit 100
  loop
    krd := string2id_krd(djr.ket_djr,'/3.',1,13,'');
	depan := substring(djr.ket_djr,0,6);
	amortype := null;
	if krd is not null then
	  case depan
	    when 'Adm K' then 
		  amortype := 'A';
	    when 'Provi' then 
		  amortype := 'P';
		when 'Fee M' then
		  amortype := 'M';
		when 'Komis' then
		  amortype := 'K';
		when 'Penga' then
		  depan2 = substring(djr.ket_djr,11,12);
		  case depan2
		    when 'Pendapatan P' then
			  amortype := 'P';
			when 'Pendapatan A' then
			  amortype := 'A';
			when 'Biaya Komisi' then
			  amortype := 'K';
			when 'Biaya Mediat' then
			  amortype := 'M';
			else 
			  -- do nothing
		  end case; -- depan2
		when 'Amort' then
		  depan2 := substring(djr.ket_djr,12,3);
		  case depan2
		    when 'Pro' then
			  amortype := 'P';
			when 'Adm' then
			  amortype := 'A';
			when 'Kom' then
			  amortype := 'K';
			when 'Med' then
			  amortype := 'M';
			else
			  -- do nothing
		  end case; -- depan2
		else
		  -- do nothing
	  end case; -- depan
	else
	  krd := string2id_krd(djr.ket_djr,'Akta ',5,7,'3.456.');
	  depan := substring(djr.ket_djr,0,6);
	  amortype := null;
      if krd is not null then
	    case depan
	      when 'Adm K' then 
		    amortype := 'A';
	      when 'Provi' then 
		    amortype := 'P';
		  when 'Fee M' then
		    amortype := 'M';
		  when 'Komis' then
		    amortype := 'K';
		  when 'Penga' then
		    depan2 = substring(djr.ket_djr,11,12);
		    case depan2
		      when 'Pendapatan P' then
			    amortype := 'P';
			  when 'Pendapatan A' then
			    amortype := 'A';
			  when 'Biaya Komisi' then
			    amortype := 'K';
			  when 'Biaya Mediat' then
			    amortype := 'M';
			  else
			    -- do nothing
		    end case;
		  when 'Amort' then
		    depan2 = substring(djr.ket_djr,11,4);
		    case depan2
		      when 'Pro' then
			    amortype := 'P';
			  when 'Adm' then
			    amortype := 'A';
			  when 'Kom' then
			    amortype := 'K';
			  when 'Med' then
			    amortype := 'M';
			  else
			    -- do nothing
		    end case;
		  else
		    -- do nothing
	    end case;
	  end if; -- krd is not null (2)
	end if; -- krd is not null (1) /3.
	if krd is not null and amortype is not null then
	  select into ae id_ae from amor_etap where id_krd = krd and id_je = amortype;
	  if (ae is not null) then
	    insert into trans_amor (id_ae,id_djr) values (ae,djr.id_djr);
		hasil := hasil + 1;
	  end if;
	end if;
  end loop;
  return hasil;
end;$BODY$;
	
CREATE OR REPLACE FUNCTION public.amr_id_krd(IN st text)
    RETURNS integer
    LANGUAGE 'plpgsql'
    VOLATILE
    PARALLEL UNSAFE
    COST 100
AS $BODY$declare
  hasil integer;
  krd integer;
  r record;
  
begin
  krd = string2id_krd(st,'/3.',1,13,'');
  if krd is null then
    krd = string2id_krd(st,'Akta ',5,7,'3.456.');
  end if;
  return krd;
end;$BODY$;

ALTER FUNCTION public.amr_id_krd(text)
    OWNER TO postgres;

COMMENT ON FUNCTION public.amr_id_krd(text)
    IS 'mencari id_krd dari keterangan';
	
CREATE OR REPLACE VIEW public.amor_info
 AS
 select id_ae,id_je,id_krd,id_djr 
 from amor_etap join trans_amor using (id_ae);

ALTER TABLE public.amor_info
    OWNER TO postgres;

CREATE OR REPLACE VIEW public.amor_list1
 AS
 select id_ae,entry_op_xdep,id_djr, tgl_djr,id_coa, no_coa,nama_coa
   , ket_djr, debet_djr, kredit_djr
   , id_je,id_krd
   , id_jr,bukti_jr,ket_jr ,tglbuku_jr
   ,amr_id_krd(ket_djr) as krd1
   from jurnal_detil join coa using (id_coa) join transjr using(id_jr)
   left join amor_info using(id_djr)
   where tgl_djr >= '2020-1-1' 
   and (id_coa = 500 or id_coa=501 or id_coa=503 or id_coa=504 or id_coa=505 or id_coa=506)
   order by id_ae desc ,tgl_djr desc;

ALTER TABLE public.amor_list1
    OWNER TO postgres;
	
CREATE OR REPLACE VIEW public.amr_kredit_adm
 AS
select id_krd,id_coa,sum(debet_djr) as debet,sum(kredit_djr) as kredit, nilai_ae,amor_ae,sisa_ae
   from kredit join amor_etap using (id_krd)
     join trans_amor using (id_ae)
	 join jurnal_detil using (id_djr)
   where  id_je = 'A'
   group by id_krd,id_coa,nilai_ae,amor_ae,sisa_ae
   order by id_krd;  ;

ALTER TABLE public.amr_kredit_adm
    OWNER TO postgres;
	
CREATE OR REPLACE VIEW public.amr_kredit_prv
 AS
select id_krd,id_coa,sum(debet_djr) as debet,sum(kredit_djr) as kredit, nilai_ae,amor_ae,sisa_ae
   from kredit join amor_etap using (id_krd)
     join trans_amor using (id_ae)
	 join jurnal_detil using (id_djr)
   where  id_je = 'P'
   group by id_krd,id_coa,nilai_ae,amor_ae,sisa_ae
   order by id_krd  ;

ALTER TABLE public.amr_kredit_prv
    OWNER TO postgres;	
	
CREATE OR REPLACE VIEW public.amr_kredit_komisi
 AS
select id_krd,id_coa,sum(debet_djr) as debet,sum(kredit_djr) as kredit, nilai_ae,amor_ae,sisa_ae
   from kredit join amor_etap using (id_krd)
     join trans_amor using (id_ae)
	 join jurnal_detil using (id_djr)
   where  id_je = 'K'
   group by id_krd,id_coa,nilai_ae,amor_ae,sisa_ae
   order by id_krd ;

ALTER TABLE public.amr_kredit_komisi
    OWNER TO postgres;
	
CREATE OR REPLACE VIEW public.amr_kredit_mediator
 AS
 select id_krd,id_coa,sum(debet_djr) as debet,sum(kredit_djr) as kredit, nilai_ae,amor_ae,sisa_ae
   from kredit join amor_etap using (id_krd)
     join trans_amor using (id_ae)
	 join jurnal_detil using (id_djr)
   where  id_je = 'M'
   group by id_krd,id_coa,nilai_ae,amor_ae,sisa_ae
   order by id_krd ;

ALTER TABLE public.amr_kredit_mediator
    OWNER TO postgres;	
	
CREATE OR REPLACE VIEW public.amr_adm1
 AS
select id_krd, akta_krd,typebunga_krd, mulai_krd,active_krd,bln_krd,akhir_krd
  ,tgl_lunas_krd,by_adm,id_coa,debet, kredit, nilai_ae,amor_ae,sisa_ae
  from kredit left join amr_kredit_adm using(id_krd)
  where akhir_krd >= '2020-1-1' and (tgl_lunas_krd >= '2020-1-1' or tgl_lunas_krd is null )
    and not (not active_krd and tgl_lunas_krd is null)
  order by mulai_krd desc;

ALTER TABLE public.amr_adm1
    OWNER TO postgres;

CREATE OR REPLACE VIEW public.amr_komisi1
 AS
SELECT kredit.id_krd,
    kredit.akta_krd,
    kredit.typebunga_krd,
    kredit.mulai_krd,
    kredit.active_krd,
    kredit.bln_krd,
    kredit.akhir_krd,
    kredit.tgl_lunas_krd,
    kredit.komisi_krd,
    kredit.tgl_komisi_krd,
    amr_kredit_mediator.id_coa,
    amr_kredit_mediator.debet,
    amr_kredit_mediator.kredit,
    amr_kredit_mediator.nilai_ae,
    amr_kredit_mediator.amor_ae,
    amr_kredit_mediator.sisa_ae
	
   FROM kredit
     LEFT JOIN amr_kredit_mediator USING (id_krd)
  WHERE kredit.akhir_krd >= '2020-01-01'::date AND (kredit.tgl_lunas_krd >= '2020-01-01'::date OR kredit.tgl_lunas_krd IS NULL) AND NOT (NOT kredit.active_krd AND kredit.tgl_lunas_krd IS NULL) AND kredit.komisi_krd > 0::numeric
  ORDER BY kredit.mulai_krd DESC;

ALTER TABLE public.amr_komisi1
    OWNER TO postgres;

CREATE OR REPLACE VIEW public.amr_mediator1
    AS
     SELECT kredit.id_krd,
    kredit.akta_krd,
    kredit.typebunga_krd,
    kredit.mulai_krd,
    kredit.active_krd,
    kredit.bln_krd,
    kredit.akhir_krd,
    kredit.tgl_lunas_krd,
    kredit.mediator_krd,
    kredit.tgl_mediator_krd,
    amr_kredit_mediator.id_coa,
    amr_kredit_mediator.debet,
    amr_kredit_mediator.kredit,
    amr_kredit_mediator.nilai_ae,
    amr_kredit_mediator.amor_ae,
    amr_kredit_mediator.sisa_ae
	
   FROM kredit
     LEFT JOIN amr_kredit_mediator USING (id_krd)
  WHERE kredit.akhir_krd >= '2020-01-01'::date AND (kredit.tgl_lunas_krd >= '2020-01-01'::date OR kredit.tgl_lunas_krd IS NULL) AND NOT (NOT kredit.active_krd AND kredit.tgl_lunas_krd IS NULL) AND kredit.mediator_krd > 0::numeric
  ORDER BY kredit.mulai_krd DESC;
	
CREATE OR REPLACE VIEW public.amr_adm1
    AS
     SELECT kredit.id_krd,
    kredit.akta_krd,
    kredit.typebunga_krd,
    kredit.mulai_krd,
    kredit.active_krd,
    kredit.bln_krd,
    kredit.akhir_krd,
    kredit.tgl_lunas_krd,
    kredit.by_adm,
    amr_kredit_adm.id_coa,
    amr_kredit_adm.debet,
    amr_kredit_adm.kredit,
    amr_kredit_adm.nilai_ae,
    amr_kredit_adm.amor_ae,
    amr_kredit_adm.sisa_ae
   FROM kredit
     LEFT JOIN amr_kredit_adm USING (id_krd)
  WHERE by_adm > 0 and kredit.akhir_krd >= '2020-01-01'::date AND (kredit.tgl_lunas_krd >= '2020-01-01'::date OR kredit.tgl_lunas_krd IS NULL) AND NOT (NOT kredit.active_krd AND kredit.tgl_lunas_krd IS NULL)
  ORDER BY kredit.mulai_krd DESC;	

CREATE OR REPLACE VIEW public.amr_provisi1
 AS
SELECT kredit.id_krd,
    kredit.akta_krd,
    kredit.typebunga_krd,
    kredit.mulai_krd,
    kredit.active_krd,
    kredit.bln_krd,
    kredit.akhir_krd,
    kredit.tgl_lunas_krd,
    kredit.by_provisi,
    amr_kredit_prv.id_coa,
    amr_kredit_prv.debet,
    amr_kredit_prv.kredit,
    amr_kredit_prv.nilai_ae,
    amr_kredit_prv.amor_ae,
    amr_kredit_prv.sisa_ae
   FROM kredit
     LEFT JOIN amr_kredit_prv USING (id_krd)
  WHERE by_provisi > 0 and kredit.akhir_krd >= '2020-01-01'::date AND (kredit.tgl_lunas_krd >= '2020-01-01'::date OR kredit.tgl_lunas_krd IS NULL) AND NOT (NOT kredit.active_krd AND kredit.tgl_lunas_krd IS NULL)
  ORDER BY kredit.mulai_krd DESC;

ALTER TABLE public.amr_provisi1
    OWNER TO postgres;

DROP VIEW public.amr_komisi1;
CREATE OR REPLACE VIEW public.amr_komisi1
    AS
    SELECT kredit.id_krd,
    kredit.akta_krd,
    kredit.typebunga_krd,
    kredit.mulai_krd,
    kredit.active_krd,
    kredit.bln_krd,
    kredit.akhir_krd,
    kredit.tgl_lunas_krd,
    kredit.komisi_krd,
    kredit.tgl_komisi_krd,
    amr_kredit_komisi.id_coa,
    amr_kredit_komisi.debet,
    amr_kredit_komisi.kredit,
    amr_kredit_komisi.nilai_ae,
    amr_kredit_komisi.amor_ae,
    amr_kredit_komisi.sisa_ae
   FROM kredit
     LEFT JOIN amr_kredit_komisi USING (id_krd)
  WHERE kredit.akhir_krd >= '2020-01-01'::date AND (kredit.tgl_lunas_krd >= '2020-01-01'::date OR kredit.tgl_lunas_krd IS NULL) AND NOT (NOT kredit.active_krd AND kredit.tgl_lunas_krd IS NULL) AND kredit.komisi_krd > 0::numeric
  ORDER BY kredit.mulai_krd DESC;
COMMENT ON VIEW public.amr_komisi1
    IS '';

CREATE OR REPLACE FUNCTION public.string2id_krd(IN st character varying,IN header character varying,IN fr integer,IN lg integer,IN prefix character varying)
    RETURNS integer
    LANGUAGE 'plpgsql'
    VOLATILE
    PARALLEL UNSAFE
    COST 100
AS $BODY$declare
  hasil integer;
  posisi integer;
  akta text;
  krd record;

begin
  posisi = position(header in st);
  akta = prefix || substring(st from posisi+fr for lg);
  for krd in select * from kredit where akta_krd = akta
  loop
    if krd.active_krd then
	  hasil := krd.id_krd;
	else
	  if (krd.tgl_lunas_krd is not null) then
	    hasil := krd.id_krd;
	  end if;
	end if; -- krd_active
  end loop;
  return hasil;
end;$BODY$;

CREATE OR REPLACE FUNCTION public.generate_trans_amor(IN coa integer)
    RETURNS integer
    LANGUAGE 'plpgsql'
    VOLATILE
    PARALLEL UNSAFE
    COST 100
AS $BODY$declare
  hasil integer;
  djr record;
  amortype text;
  krd integer;
  ae integer;
  depan text;
  depan2 text;
  depan3 text;

begin
  hasil := 0;
  for djr in  select id_djr, ket_djr from jurnal_detil where id_coa = coa
    --limit 100
  loop
    krd := string2id_krd(djr.ket_djr,'/3.',1,13,'');
	depan := substring(djr.ket_djr,0,6);
	amortype := null;
	if krd is not null then
	  case depan
	    when 'Adm K' then 
		  amortype := 'A';
	    when 'Provi' then 
		  amortype := 'P';
		when 'Fee M' then
		  amortype := 'M';
		when 'Komis' then
		  amortype := 'K';
		when 'Penga' then
		  depan2 = substring(djr.ket_djr,11,12);
		  case depan2
		    when 'Pendapatan P' then
			  amortype := 'P';
			when 'Pendapatan A' then
			  amortype := 'A';
			when 'Biaya Komisi' then
			  depan3 = substring(djr.ket_djr,11,21);
			  if depan3 = 'Biaya Komisi Mediator' then
			    amortype := 'M';
			  else
			    amortype := 'K';
			  end if;
			when 'Biaya Mediat' then
			  amortype := 'M';
			else 
			  -- do nothing
		  end case; -- depan2
		when 'Amort' then
		  depan2 := substring(djr.ket_djr,12,3);
		  case depan2
		    when 'Pro' then
			  amortype := 'P';
			when 'Adm' then
			  amortype := 'A';
			when 'Kom' then
			  amortype := 'K';
			when 'Med' then
			  amortype := 'M';
			else
			  -- do nothing
		  end case; -- depan2
		else
		  -- do nothing
	  end case; -- depan
	else
	  krd := string2id_krd(djr.ket_djr,'Akta ',5,7,'3.456.');
	  depan := substring(djr.ket_djr,0,6);
	  amortype := null;
      if krd is not null then
	    case depan
	      when 'Adm K' then 
		    amortype := 'A';
	      when 'Provi' then 
		    amortype := 'P';
		  when 'Fee M' then
		    amortype := 'M';
		  when 'Komis' then
		    amortype := 'K';
		  when 'Penga' then
		    depan2 = substring(djr.ket_djr,11,12);
		    case depan2
		      when 'Pendapatan P' then
			    amortype := 'P';
			  when 'Pendapatan A' then
			    amortype := 'A';
			  when 'Biaya Komisi' then
			    depan3 = substring(djr.ket_djr,11,21);
			    if depan3 = 'Biaya Komisi Mediator' then
			      amortype := 'M';
			    else
			      amortype := 'K';
			    end if;
			  when 'Biaya Mediat' then
			    amortype := 'M';
			  else
			    -- do nothing
		    end case;
		  when 'Amort' then
		    depan2 = substring(djr.ket_djr,11,4);
		    case depan2
		      when 'Pro' then
			    amortype := 'P';
			  when 'Adm' then
			    amortype := 'A';
			  when 'Kom' then
			    amortype := 'K';
			  when 'Med' then
			    amortype := 'M';
			  else
			    -- do nothing
		    end case;
		  else
		    -- do nothing
	    end case;
	  end if; -- krd is not null (2)
	end if; -- krd is not null (1) /3.
	if krd is not null and amortype is not null then
	  select into ae id_ae from amor_etap where id_krd = krd and id_je = amortype;
	  if (ae is not null) then
	    insert into trans_amor (id_ae,id_djr) values (ae,djr.id_djr);
		hasil := hasil + 1;
	  end if;
	end if;
  end loop;
  return hasil;
end;$BODY$;


COMMENT ON COLUMN public.jurnal_detil.note_djr
    IS 'Keterangan (optional) untuk penelusuran umum. Dibuat pada saat penelurusan amor.';

CREATE OR REPLACE VIEW public.amor_list2
 AS
  SELECT amor_info.id_ae,
    jurnal_detil.entry_op_xdep,
    jurnal_detil.id_djr,
    jurnal_detil.tgl_djr,
    jurnal_detil.id_coa,
    coa.no_coa,
    coa.nama_coa,
    jurnal_detil.ket_djr,
    jurnal_detil.debet_djr,
    jurnal_detil.kredit_djr,
    amor_info.id_je,
    amor_info.id_krd,
    jurnal_detil.id_jr,
    transjr.bukti_jr,
    transjr.ket_jr,
    transjr.tglbuku_jr,
    amr_id_krd(jurnal_detil.ket_djr::text) AS krd1,
	note_djr
   FROM jurnal_detil
     JOIN coa USING (id_coa)
     JOIN transjr USING (id_jr)
     LEFT JOIN amor_info USING (id_djr)
  WHERE jurnal_detil.tgl_djr >= '2020-01-01'::date AND (jurnal_detil.id_coa = 500 OR jurnal_detil.id_coa = 501 OR jurnal_detil.id_coa = 503 OR jurnal_detil.id_coa = 504 OR jurnal_detil.id_coa = 505 OR jurnal_detil.id_coa = 506)
  ORDER BY amor_info.id_ae DESC, jurnal_detil.tgl_djr DESC;

ALTER TABLE public.amor_list2
    OWNER TO postgres;


 delete from trans_amor;
 select generate_trans_amor(500);
 select generate_trans_amor(501);
 select generate_trans_amor(503);
 select generate_trans_amor(504);
 select generate_trans_amor(505);
 select generate_trans_amor(506);
 
 -- BPR
insert into trans_amor (id_ae,id_djr) values (19178,5874065);  
insert into trans_amor (id_ae,id_djr) values (18953,5857456); 
insert into trans_amor (id_ae,id_djr) values (18932,5858926); 
insert into trans_amor (id_ae,id_djr) values (18952,5860431); 
insert into trans_amor (id_ae,id_djr) values (18951,5861077); 
insert into trans_amor (id_ae,id_djr) values (18985,5863410); 
insert into trans_amor (id_ae,id_djr) values (19081,5868445); 
insert into trans_amor (id_ae,id_djr) values (19125,5870906); 
insert into trans_amor (id_ae,id_djr) values (19225,5876967); 
insert into trans_amor (id_ae,id_djr) values (19374,5889235); 
insert into trans_amor (id_ae,id_djr) values (19522,5901893); 
insert into trans_amor (id_ae,id_djr) values (19523,5902358);  

update jurnal_detil set note_djr = 'tanya no akta' where id_djr = 5858017; 
update jurnal_detil set note_djr = 'tanya no akta' where id_djr = 5864871; 
update jurnal_detil set note_djr = 'tanya no akta' where id_djr = 5864875; 
update jurnal_detil set note_djr = 'tanya no akta' where id_djr = 5871330; 
update jurnal_detil set note_djr = 'tanya no akta' where id_djr = 5876396; 
update jurnal_detil set note_djr = 'tanya no akta' where id_djr = 5897029; 
update jurnal_detil set note_djr = 'tanya no akta' where id_djr = 5902862; 
update jurnal_detil set note_djr = 'tanya no akta' where id_djr = 5902866; 
update jurnal_detil set note_djr = 'Fee mediator tidak tercatat pada tabel kredit' where id_djr = 5908728; 
update jurnal_detil set note_djr = 'Tertulis di jurnal sebagai [Fee Bunga dan Administrasi]. Hasil penelurusan menunjukan ini adalah transaksi Mediator' where id_djr = 5857456; 
update jurnal_detil set note_djr = 'tanya no akta' where id_djr = 5858023; 
update jurnal_detil set note_djr = 'Tertulis di jurnal sebagai [Fee Bunga dan Administrasi]. Hasil penelurusan menunjukan ini adalah transaksi Mediator' where id_djr = 5858926; 
update jurnal_detil set note_djr = 'Tertulis di jurnal sebagai [Fee Bunga dan Administrasi]. Hasil penelurusan menunjukan ini adalah transaksi Mediator' where id_djr = 5860431; 
update jurnal_detil set note_djr = 'Tertulis di jurnal sebagai [Fee Bunga dan Administrasi]. Hasil penelurusan menunjukan ini adalah transaksi Mediator' where id_djr = 5861077; 
update jurnal_detil set note_djr = 'Tertulis di jurnal sebagai [Fee Bunga dan Administrasi]. Hasil penelurusan menunjukan ini adalah transaksi Mediator' where id_djr = 5863410; 
update jurnal_detil set note_djr = 'tanya no akta' where id_djr = 5864873; 
update jurnal_detil set note_djr = 'tanya no akta' where id_djr = 5864877; 
update jurnal_detil set note_djr = 'Tertulis di jurnal sebagai [Fee Bunga dan Administrasi]. Hasil penelurusan menunjukan ini adalah transaksi Mediator' where id_djr = 5868445; 
update jurnal_detil set note_djr = 'Tertulis di jurnal sebagai [Fee Bunga dan Administrasi]. Hasil penelurusan menunjukan ini adalah transaksi Mediator' where id_djr = 5870906; 
update jurnal_detil set note_djr = 'tanya no akta (Nilai = 0)' where id_djr = 5871327; 
update jurnal_detil set note_djr = 'tanya no akta (Nilai = 0)' where id_djr = 5876394; 
update jurnal_detil set note_djr = 'tanya no akta' where id_djr = 5876398; 
update jurnal_detil set note_djr = 'Tertulis di jurnal sebagai [Fee Bunga dan Administrasi]. Hasil penelurusan menunjukan ini adalah transaksi Mediator' where id_djr = 5876967; 
update jurnal_detil set note_djr = 'tanya no akta' where id_djr = 5884053; 
update jurnal_detil set note_djr = 'Tertulis di jurnal sebagai [Fee Bunga dan Administrasi]. Hasil penelurusan menunjukan ini adalah transaksi Mediator' where id_djr = 5889235; 
update jurnal_detil set note_djr = 'tanya no akta' where id_djr = 5897025; 
update jurnal_detil set note_djr = 'Tertulis di jurnal sebagai [Fee Bunga dan Administrasi]. Hasil penelurusan menunjukan ini adalah transaksi Mediator' where id_djr = 5901893; 
update jurnal_detil set note_djr = 'Tertulis di jurnal sebagai [Fee Bunga dan Administrasi]. Hasil penelurusan menunjukan ini adalah transaksi Mediator' where id_djr = 5902358; 
update jurnal_detil set note_djr = 'tanya no akta' where id_djr = 5902864; 
update jurnal_detil set note_djr = 'tanya no akta' where id_djr = 5902868; 
update jurnal_detil set note_djr = 'tanya no akta' where id_djr = 5908703; 
update jurnal_detil set note_djr = 'mediator_krd kosong, id_krd = 28283, tapi ada transaksi Mediator Rp 350.000. Dugaan : Mediator belum di entry pada saat database ini di backup (jam 9; 12 Mei 2020)' where id_djr = 5908722; 
 
 -- end BPR
 
 -- test tool jangan dijalankan hanya untuk analisa
 select id_djr, ket_djr,string2id_krd(ket_djr,'/3.',1,13,'') as krd 
,string2id_krd(ket_djr,'Akta ',5,7,'3.456.') as krd2
,substring(ket_djr,0,6) as depan
  from jurnal_detil where id_djr = 5908722
  
select id_krd,by_adm,by_provisi,komisi_krd,mediator_krd,active_krd, tgl_lunas_krd  from kredit join reknas using(id_rek) join nasabah using (id_nas) 
  where akta_krd = '3.456.3037369'

select id_krd, nama_nas,by_adm,by_provisi,komisi_krd,mediator_krd,active_krd, tgl_lunas_krd, akta_krd
from kredit join reknas using(id_rek) join nasabah using (id_nas)  where id_krd = 28283
  
select * from amor_etap where id_krd = 28283

select * from amor_etap where id_ae = 19523

-- link : https://docs.google.com/spreadsheets/d/10ZWCRkdXMJhm5k0uKzrWamnqNU3srjJ4Rjdu9ZdicqY/edit?usp=sharing
-- end of test tool