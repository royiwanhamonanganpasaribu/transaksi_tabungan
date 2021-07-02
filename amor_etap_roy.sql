-- Function: public.amor_etap()

-- DROP FUNCTION public.amor_etap();

CREATE OR REPLACE FUNCTION public.amor_etap()
  RETURNS integer AS
$BODY$declare

  nojur int4;
  nojur_id_djr int4;
  nojur_id_ae int4;
  acr record;
  je record;
  jem record;
  jed int4;
  jek int4;
  nocoa int4;
  skr date;
  bt text;
  keter text;
  amorbini numeric(15,0);
  jedbt int4;
  jekrd int4;

begin 

 skr := sekarang();
  nojur := 0;
  nojur_id_djr := 0;
  nojur_id_ae := 0;

-- P R O V I S I 
  select into je * from jenis_etap where id_je = 'P';
  for acr in select prov_daily_amor.*, nama_nas, akta_krd
      from prov_daily_amor
        join kredit using (id_krd)
        join reknas using (id_rek)
        join nasabah using (id_nas)
      where amor_bulanini > 0  
      order by kredit.id_krd
  loop
    if nojur = 0 then
      nojur := nextval('transjr_id_jr_seq');
      bt := no_ledger('77');
      insert into transjr (
        id_jr,id_com,entryop_jr,tglbuku_jr,ket_jr,
        posted_jr, bukti_jr
        ) values (
        nojur,'1','System',skr,'Jurnal Amortisasi Etap',
        skr, bt
      );
    end if;

    if substr(acr.akta_krd,7,1) ='1' then
      jedbt := je.d1_je;
      jekrd := je.k1_je;
    elseif substr(acr.akta_krd,7,1) ='2' then
      jedbt := je.d2_je;
      jekrd := je.k2_je;   
    else
      jedbt := je.d3_je;
      jekrd := je.k3_je;
    end if;

    insert into jurnal_detil (
        id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,
        entry_op_xdep, posted_djr,ket_djr
         ) values (
           nojur,skr, jedbt,acr.amor_bulanini,0,
           'System',true,'Amortisasi Provisi '|| acr.nama_nas||'/'||acr.akta_krd
         );
    insert into jurnal_detil (
        id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,
        entry_op_xdep, posted_djr,ket_djr
         ) values (
           nojur,skr, jekrd,0,acr.amor_bulanini,
           'System',true,'Amortisasi Provisi '|| acr.nama_nas||'/'||acr.akta_krd
         );

     update amor_etap
       set  sisa_ae = sisa_ae - acr.amor_bulanini
       where id_krd = acr.id_krd and id_je = 'P' ;
  end loop;
  
  -- A D M

  select into je * from jenis_etap where id_je = 'A';
  for acr in select adm_daily_amor.*, nama_nas, akta_krd
      from adm_daily_amor
        join kredit using (id_krd)
        join reknas using (id_rek)
        join nasabah using (id_nas)
      where amor_bulanini > 0  
      order by kredit.id_krd
  loop
    if nojur = 0 then
      nojur := nextval('transjr_id_jr_seq');
      bt := no_ledger('77');
      insert into transjr (
        id_jr,id_com,entryop_jr,tglbuku_jr,ket_jr,
        posted_jr, bukti_jr
        ) values (
        nojur,'1','System',skr,'Jurnal Amortisasi Etap',
        skr, bt
      );
    end if;

    if substr(acr.akta_krd,7,1) ='1' then
      jedbt := je.d1_je;
      jekrd := je.k1_je;
    elseif substr(acr.akta_krd,7,1) ='2' then
      jedbt := je.d2_je;
      jekrd := je.k2_je;   
    else
      jedbt := je.d3_je;
      jekrd := je.k3_je;
    end if;

    insert into jurnal_detil (
        id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,
        entry_op_xdep, posted_djr,ket_djr
         ) values (
           nojur,skr, jedbt,acr.amor_bulanini,0,
           'System',true,'Amortisasi Adm '|| acr.nama_nas||'/'||acr.akta_krd
         );

    insert into jurnal_detil (
        id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,
        entry_op_xdep, posted_djr,ket_djr
         ) values (
           nojur,skr, jekrd,0,acr.amor_bulanini,
           'System',true,'Amortisasi Adm '|| acr.nama_nas||'/'||acr.akta_krd
         );

     update amor_etap
       set  sisa_ae = sisa_ae - acr.amor_bulanini
       where id_krd = acr.id_krd and id_je = 'A' ;

  end loop;

  -- MEDIATOR INADVANCE

  select into jem * from jenis_etap where id_je = 'M';
  for acr in select kredit.*, amor_etap.*, nama_nas 
    from kredit join amor_etap using (id_krd) join reknas using (id_rek) join nasabah using (id_nas)
    where tgl_mediator_krd = sekarang() and id_je = 'M' and kredit.typebunga_krd = 'A'  order by akta_krd
  loop
    if nojur = 0 then
      nojur := nextval('transjr_id_jr_seq');
      bt := no_ledger('77');

      insert into transjr (
        id_jr,id_com,entryop_jr,tglbuku_jr,ket_jr,
        posted_jr, bukti_jr
        ) values (
        nojur,'1','System',skr,'Jurnal Amortisasi Etap',
        skr, bt
      );
    end if;

    if acr.id_je = 'M' then
        keter = 'Amortisasi Mediator ';
        if substr(acr.akta_krd,7,1) ='1' then
          jek := jem.k1_je;
          jed := jem.d1_je;
        elseif substr(acr.akta_krd,7,1) ='2' then
          jek := jem.k2_je;
          jed := jem.d2_je;   
        else
         jek := jem.k3_je;
         jed := jem.d3_je;
        end if;
    end if;

    insert into jurnal_detil (
        id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,
        entry_op_xdep, posted_djr,ket_djr
         ) values (
           nojur,skr, jed,acr.amor_ae,0,
           'System',true,keter|| acr.nama_nas||'/'||acr.akta_krd
         );

    insert into jurnal_detil (
        id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,
        entry_op_xdep, posted_djr,ket_djr
         ) values (
           nojur,skr, jek,0,acr.amor_ae,
           'System',true,keter|| acr.nama_nas||'/'||acr.akta_krd
         );
    
     update amor_etap
       set  sisa_ae = sisa_ae - acr.amor_ae
       where id_krd = acr.id_krd and id_je = 'M' ;
  end loop;

-- K O M I S I INADVANCE
  select into jem * from jenis_etap where id_je = 'K';
  for acr in select kredit.*, amor_etap.*, nama_nas 
    from kredit join amor_etap using (id_krd) join reknas using (id_rek) join nasabah using (id_nas)
    where tgl_komisi_krd = sekarang() and id_je = 'K' and kredit.typebunga_krd = 'A' order by akta_krd
  loop
    if nojur = 0 then
      nojur := nextval('transjr_id_jr_seq');
      bt := no_ledger('77');

      insert into transjr (
        id_jr,id_com,entryop_jr,tglbuku_jr,ket_jr,
        posted_jr, bukti_jr
        ) values (
        nojur,'1','System',skr,'Jurnal Amortisasi Etap',
        skr, bt
      );
    end if;

    if acr.id_je = 'K' then
        keter = 'Amortisasi Komisi ';
        if substr(acr.akta_krd,7,1) ='1' then
          jek := jem.k1_je;
          jed := jem.d1_je;
        elseif substr(acr.akta_krd,7,1) ='2' then
          jek := jem.k2_je;
          jed := jem.d2_je;   
        else
         jek := jem.k3_je;
         jed := jem.d3_je;
        end if;
    end if;

    insert into jurnal_detil (
        id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,
        entry_op_xdep, posted_djr,ket_djr
         ) values (
           nojur,skr, jed,acr.amor_ae,0,
           'System',true,keter|| acr.nama_nas||'/'||acr.akta_krd
         );

    insert into jurnal_detil (
        id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,
        entry_op_xdep, posted_djr,ket_djr
         ) values (
           nojur,skr, jek,0,acr.amor_ae,
           'System',true,keter|| acr.nama_nas||'/'||acr.akta_krd
         );
    
     update amor_etap
       set  sisa_ae = sisa_ae - acr.amor_ae
       where id_krd = acr.id_krd and id_je = 'K' ;
  end loop;

-- KOMISI AND MEDIATOR INADVANCE

select into je * from jenis_etap where id_je = 'K';
  select into jem * from jenis_etap where id_je = 'M';
  for acr in select komisi_daily_amor.*, nasabah.nama_nas,kredit.akta_krd
      from komisi_daily_amor
        join kredit using (id_krd)
        join reknas using (id_rek)
        join nasabah using (id_nas)
        join amor3_age using (id_krd)
      where amor_bulanini > 0  and amor3_age.bln_ke >=2 and kredit.typebunga_krd = 'A'
      order by kredit.id_krd 
  loop
    if nojur = 0 then
      nojur := nextval('transjr_id_jr_seq');
      bt := no_ledger('77');

      insert into transjr (
        id_jr,id_com,entryop_jr,tglbuku_jr,ket_jr,
        posted_jr, bukti_jr
        ) values (
        nojur,'1','System',skr,'Jurnal Amortisasi Etap',
        skr, bt
      );
    end if;

    if acr.id_je = 'K' then
        keter = 'Amortisasi Komisi ';
        if substr(acr.akta_krd,7,1) ='1' then
          jek := je.k1_je;
          jed := je.d1_je;
        elseif substr(acr.akta_krd,7,1) ='2' then
          jek := je.k2_je;
          jed := je.d2_je;   
        else
          jek := je.k3_je;
          jed := je.d3_je;
        end if;
		
       update amor_etap
         set  sisa_ae = sisa_ae - acr.amor_bulanini
         where id_krd = acr.id_krd and id_je = 'K' ;
    else
        keter = 'Amortisasi Mediator ';
        if substr(acr.akta_krd,7,1) ='1' then
          jek := jem.k1_je;
          jed := jem.d1_je;
        elseif substr(acr.akta_krd,7,1) ='2' then
          jek := jem.k2_je;
          jed := jem.d2_je;   
        else
         jek := jem.k3_je;
         jed := jem.d3_je;
        end if;
		
		update amor_etap
         set  sisa_ae = sisa_ae - acr.amor_bulanini
         where id_krd = acr.id_krd and id_je = 'M' ;
    end if;

    insert into jurnal_detil (
        id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,
        entry_op_xdep, posted_djr,ket_djr
         ) values (
           nojur,skr, jed,acr.amor_bulanini,0,
           'System',true,keter|| acr.nama_nas||'/'||acr.akta_krd
         );

    insert into jurnal_detil (
        id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,
        entry_op_xdep, posted_djr,ket_djr
         ) values (
           nojur,skr, jek,0,acr.amor_bulanini,
           'System',true,keter|| acr.nama_nas||'/'||acr.akta_krd
         );
    end loop;

-- KOMISI AND MEDIATOR NOT INADVANCE

  select into je * from jenis_etap where id_je = 'K';
  select into jem * from jenis_etap where id_je = 'M';
  for acr in select komisi_daily_amor.*, nasabah.nama_nas,kredit.akta_krd
      from komisi_daily_amor
        join kredit using (id_krd)
        join reknas using (id_rek)
        join nasabah using (id_nas)
        join amor3_age using (id_krd)
      where amor_bulanini > 0  and amor3_age.bln_ke >=1 and kredit.typebunga_krd <> 'A'
      order by kredit.id_krd 
  loop
    if nojur = 0 then
      nojur := nextval('transjr_id_jr_seq');
      bt := no_ledger('77');

      insert into transjr (
        id_jr,id_com,entryop_jr,tglbuku_jr,ket_jr,
        posted_jr, bukti_jr
        ) values (
        nojur,'1','System',skr,'Jurnal Amortisasi Etap',
        skr, bt
      );
    end if;

    if acr.id_je = 'K' then
        keter = 'Amortisasi Komisi ';
        if substr(acr.akta_krd,7,1) ='1' then
          jek := je.k1_je;
          jed := je.d1_je;
        elseif substr(acr.akta_krd,7,1) ='2' then
          jek := je.k2_je;
          jed := je.d2_je;   
        else
          jek := je.k3_je;
          jed := je.d3_je;
        end if;
		
       update amor_etap
         set  sisa_ae = sisa_ae - acr.amor_bulanini
         where id_krd = acr.id_krd and id_je = 'K' ;
    else
        keter = 'Amortisasi Mediator ';
        if substr(acr.akta_krd,7,1) ='1' then
          jek := jem.k1_je;
          jed := jem.d1_je;
        elseif substr(acr.akta_krd,7,1) ='2' then
          jek := jem.k2_je;
          jed := jem.d2_je;   
        else
         jek := jem.k3_je;
         jed := jem.d3_je;
        end if;
		
		update amor_etap
         set  sisa_ae = sisa_ae - acr.amor_bulanini
         where id_krd = acr.id_krd and id_je = 'M' ;
    end if;

    insert into jurnal_detil (
        id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,
        entry_op_xdep, posted_djr,ket_djr
         ) values (
           nojur,skr, jed,acr.amor_bulanini,0,
           'System',true,keter|| acr.nama_nas||'/'||acr.akta_krd
         );

    insert into jurnal_detil (
        id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,
        entry_op_xdep, posted_djr,ket_djr
         ) values (
           nojur,skr, jek,0,acr.amor_bulanini,
           'System',true,keter|| acr.nama_nas||'/'||acr.akta_krd
         );
    end loop;

  select into je * from jenis_etap where id_je = 'P';
  for acr in select prov_daily_amor.*, nama_nas, akta_krd,amor_etap.id_ae,jurnal_detil.id_djr
      from prov_daily_amor
        join kredit using (id_krd)
        join reknas using (id_rek)
        join nasabah using (id_nas)
        join jurnal_detil using (id_jr)
	join amor_etap using (id_krd)
        join trans_amor using (id_djr)
      where amor_bulanini > 0  
      order by kredit.id_krd
  loop
     nojur_id_ae := nextval('amor_etap_id_ae_seq');
      nojur_id_djr := nextval('jurnal_detil_id_djr_seq');

      insert into trans_amor (
          id_ae,id_djr
        ) values (
       id_ae,id_djr
      );
  end loop;
  return 1;

end; -- end of amor_etap()

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION public.amor_etap()
  OWNER TO bprdba;
