  select into je * from jenis_etap where id_je = 'M';
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

      insert into trans_amor (id_ae,id_djr) values (acr.nojur_id_ae,acr.nojur_id_djr);
  end loop;