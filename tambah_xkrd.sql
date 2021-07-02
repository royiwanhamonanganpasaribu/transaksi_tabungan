-- Function: public.tambah_xkrd()

-- DROP FUNCTION public.tambah_xkrd();

CREATE OR REPLACE FUNCTION public.tambah_xkrd()
  RETURNS trigger AS
$BODY$-- 11 jan 08 accrue
-- 30 okt 07 tambah_xkrd
-- 25 jan koreksi nomor akta akta_kredit()
-- 19 mei 2020 koreksi amor

declare
  p record;
  kode char(2);
  xjr int4;
  k numeric(15,2);
  d numeric(15,2);
  nocoa int4;
  nocoa2 int4;
  kr record;
  d2 numeric(15,2);
  norektab character(13);
  kt character(100);
  rk record;
  kt2 text;
  nilai numeric(15,2);
  nilai_amor numeric(15,2);
  skr date;
  bkt character(10);
  a record;
  j record;
  ka text;
  akta text;
  sadm text;
  sprov text;
  jedbt int4;
  jekrd int4;
  iddebet int4;
  idkredit int4;
  idae int4;
  
-- dari OB-Sheet
  baki numeric(15,0);
  bg numeric(15,0);
-- selesai dari OB-Sheet

begin
  skr := sekarang();
  new.tgl_lunas_pokok_xkrd := new.tglproses_xkrd;
  if new.proses_xkrd = true then
    -- ubah outstanding di kredit
    if new.id_sandi = '38' or new.id_sandi = '39' then /* hapus buku & hapus tagih */
     -- tidak perlu edit kredit lagi supaya tidak recursive, karena di ubah_kredit panggil tambah_xkrd
     -- perlu generate transaksi proses
    else
      update kredit set 
        baki_krd=baki_krd+new.pokokt_xkrd-new.pokokk_xkrd, 
        osbunga_krd=osbunga_krd+new.bungat_xkrd-new.bungak_xkrd
        where id_krd = new.id_krd;
    end if;
    -- generate transaksi keuangan
    if new.id_sandi = '36' then /* pelunasan kredit */
      update kredit set active_krd = false where id_krd = new.id_krd;
      select into rk * from kredit join reknas using (id_rek)
                                   join nasabah using (id_nas)
                                   join (select id_krd, max(tgl_xkrd) as maxdate from trans_kredit 
                                           where lunas_xkrd = '1'  
                                           group by id_krd) as xkrd
                                      using (id_krd)
                       where id_krd = new.id_krd;
      kt:=rk.akta_krd;
      select akta_krd into akta  from kredit where id_krd = new.id_krd;

      if akta is null then
        akta := ' ';
      end if;
      kode:=new.id_sandi;
      insert into transjr
        (id_com,tglbuku_jr,ket_jr,
         asal_jr,kegiatan_id,acc_jr
        )
       values
        ('1',skr::date,'Pelunasan Kredit', 
         'K',new.id_xkrd,true
        );
      select into xjr currval('public.transjr_id_jr_seq');
      select into bkt bukti_jr from transjr where id_jr = xjr;
      new.bkt_xkrd = bkt ;
      kt := ' Kredit Akta '||akta_kredit(new.id_krd);
      select into kr * from kredit where id_krd = new.id_krd;
      select into norektab no_rek from reknas, kredit  
         where reknas.id_rek = kredit.ambildari_krd and id_krd = new.id_krd;
      select into nocoa id_coa from coa where no_coa = '20001';
      insert into jurnal_detil
           (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr,id_sandi
           )
           values
           (xjr,sekarang(),nocoa,
            nonul(new.pokokk_xkrd)+nonul(new.bungak_xkrd)+nonul(new.penalty_xkrd)-
            nonul(new.discbng_xkrd)+nonul(new.denda_xkrd),
            0,substring(norektab||' Pelunasan'||kt from 1 for 100),true,'14'
           );

      if kr.biguna_krd ='10' then
        select into nocoa id_coa from coa where no_coa = '13010';
      elsif kr.biguna_krd = '20' then
        select into nocoa id_coa from coa where no_coa = '13020';
      else
        select into nocoa id_coa from coa where no_coa = '13030';
      end if;
      insert into jurnal_detil
         (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr)
         values
         (xjr,sekarang(),nocoa,0,new.pokokk_xkrd,'POKOK'||kt,true);
      if new.penalty_xkrd <> 0 then
         select into nocoa id_coa from coa where no_coa = '37025';
         insert into jurnal_detil
           (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr)
           values
           (xjr,sekarang(),nocoa,0,new.penalty_xkrd,'Penalty'||kt,true);
      end if;

      if date_part('year',skr)*100+date_part('mon',skr) > date_part('year',rk.maxdate)*100+date_part('mon',rk.maxdate) then
        if date_part('d',rk.mulai_krd) >= 30 then
          nilai := 0;
        else
          nilai := round((30-date_part('d',rk.mulai_krd))*new.salp_xkrd*kr.bungaef_krd/36000);
        end if; 
      else
        nilai := 0;
      end if; -- date_part
      nilai := nonul(new.accrue_xkrd);
      if nilai <> 0 then
        select into nocoa id_coa from coa where no_coa = '14000';
        insert into jurnal_detil
          (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr)
          values
          (xjr,skr,nocoa,0,nilai,'Bunga'||kt,true);
      end if;
      if nonul(new.bungak_xkrd) - nilai - nonul(new.discbng_xkrd) <> 0 then
        select into nocoa id_coa from coa where no_coa = '30001';
        insert into jurnal_detil
          (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr)
          values
          (xjr,skr,nocoa,0,nonul(new.bungak_xkrd) - nilai - nonul(new.discbng_xkrd),'Bunga'||kt,true);
      end if;
      if new.denda_xkrd <> 0 then
        select into nocoa id_coa from coa where no_coa = '30020';
        insert into jurnal_detil
        (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr)
        values
        (xjr,sekarang(),nocoa,0,new.denda_xkrd,'Denda'||kt,true);
      end if;
      
    -- jurnal amortisasi etap
      insert into transjr
        (id_com,tglbuku_jr,ket_jr,asal_jr,kegiatan_id,acc_jr)
        values
        ('1',skr::date,'Amor Lunas '||akta,'K',new.id_xkrd,true);
      select into xjr currval('public.transjr_id_jr_seq');
      select into bkt bukti_jr from transjr where id_jr = xjr;
      for a in select sisa_amor_acc(id_krd,id_je) as sisa, amor_etap.*, kredit.akta_krd  -- koreksi_amor1 200519
        from amor_etap join kredit using(id_krd)
        where id_krd = new.id_krd and sisa_ae > 0 
        order by id_je 
    loop
      if a.sisa <> 0 then                                                              -- koreksi_amor1 200519
          select * into j from jenis_etap where id_je = a.id_je;
          if a.id_je = 'A' then
            ka := 'Pengakuan Pendapatan Adm '||kt;
      nilai_amor := a.sisa;
          elsif a.id_je = 'P' then
            ka := 'Pengakuan Pendapatan Provisi '||kt;
      nilai_amor := a.sisa;
          elsif a.id_je = 'M' then
            ka := 'Pengakuan Biaya Mediator '||kt;
      if a.sisa >= 0 then        
        nilai_amor := a.sisa;
      else
        nilai_amor := nonul(rk.mediator_krd) + a.sisa;            -- anggap bahwa debet biaya mediator sudah dilakukan dengan benar
      end if;
          else
            ka := 'Pengakuan Biaya Komisi '||kt;
      if a.sisa >= 0 then        
        nilai_amor := a.sisa;
      else
        nilai_amor := nonul(rk.komisi_krd) + a.sisa;            -- anggap bahwa debet biaya komisi sudah dilakukan dengan benar
      end if;
          end if;
      
          if substr(a.akta_krd,7,1) ='1' then
            jedbt := j.d1_je;
            jekrd := j.k1_je;
          elseif substr(a.akta_krd,7,1) ='2' then
            jedbt := j.d2_je;
            jekrd := j.k2_je;   
          else
            jedbt := j.d3_je;
            jekrd := j.k3_je;
          end if;

          iddebet := nextval('jurnal_detil_id_djr_seq');                       -- koreksi_amor1 200519
          insert into jurnal_detil
            (id_jr,id_djr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr)
            values
            (xjr,iddebet,sekarang(),jedbt,nilai_amor,0,ka,true);
      
      idkredit := nextval('jurnal_detil_id_djr_seq');                      -- koreksi_amor1 200519
          insert into jurnal_detil
            (id_jr,id_djr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr)
            values
            (xjr,idkredit,sekarang(),jekrd,0,nilai_amor,ka,true);  
      
      if a.id_je = 'A' or a.id_je='P' then                                 -- koreksi_amor1 200519
        insert into trans_amor (id_ae,id_djr,debet_xa) values (a.id_ae,iddebet,nilai_amor);    -- insert di trans_amor
      else
        insert into trans_amor (id_ae,id_djr,kredit_xa) values (a.id_ae,idkredit,nilai_amor);
      end if; -- a.id_je
      
      end if; -- a.sisa <> 0
      end loop;
    update amor_etap set sisa_ae = 0 where id_krd = new.id_krd;                       -- koreksi_amor1 200519
    -- dari OB-SHeet
    elsif new.id_sandi = '33'  then            -- angsuran kredit hapus buku / tagih. Tidak perlu generate jurnal 
      select into kr * from kredit where id_krd = new.id_krd;
      baki := kr.baki_krd - nonul(new.pokokk_xkrd);
      if baki < 0 then baki :=0; end if;
      bg := kr.osbunga_krd - nonul(new.bungak_xkrd);
      if bg < 0 then bg :=0; end if;
      if baki = 0 and bg = 0 then
        update kredit set baki_krd = baki, osbunga_krd = bg, tgl_hapus_krd = null, tgl_hapus_tagih_krd = null
          where id_krd = new.id_krd;
      else
        update kredit set baki_krd = baki, osbunga_krd = bg
          where id_krd = new.id_krd;
      end if;
    -- selesai OB-Sheet
    -- 37 = cicilan pertama in advance, sudah ditangani manual, jadi tidak perlu di generate  
  -- koreksi untuk id_sandi 37 2020-05-18. Manual tidak menangani amor id_sandi 37 (A), harus di generate oleh system
    elsif new.id_sandi <> '37'  then
      select into rk * from kredit join reknas using (id_rek)
                                   join nasabah using (id_nas)
                       where id_krd = new.id_krd;
--      select into kt akta_krd from kredit where id_krd = new.id_krd;
      kt:=rk.akta_krd;
      kode:=new.id_sandi;
      if new.id_sandi = '38' or new.id_sandi = '39' then
        -- tidak perlu generate transjr , karena dibukukan manual
      else
        insert into transjr
          (id_com,tglbuku_jr,ket_jr,bukti_jr,
           asal_jr,kegiatan_id,acc_jr,id_jr
          )
         values
          ('1',sekarang()::date,'Kredit', 'KR '||kanan(5::int2,kt),
           'K',new.id_xkrd,true,nextval('public.transjr_id_jr_seq')
          );
        select into xjr currval('public.transjr_id_jr_seq');
      end if;
      
       if new.id_sandi = '30' then /* proses khusus pencairan kredit */
         kt := '/'||rk.akta_krd||'/'||rk.nama_nas;
         select into kr * from kredit where id_krd = new.id_krd;
         if kr.biguna_krd = '10' then
           select into nocoa id_coa from coa where no_coa = '13010';
         elsif kr.biguna_krd = '20' then
           select into nocoa id_coa from coa where no_coa = '13020';
         else
           select into nocoa id_coa from coa where no_coa = '13030';
         end if;
         insert into jurnal_detil
           (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr
           )
           values
           (xjr,sekarang(),nocoa,kr.pinjaman_krd,0,'POKOK'||kt,true
           );
         if kr.by_adm > 0 then                                                           -- koreksi_amor1 200519
       select into j * from jenis_etap where id_je = 'A';
           if kr.pinjaman_krd > j.batas_je then                                          -- cek apakah diatas batas yang perlu di amor
         idae := nextval('amor_etap_id_ae_seq');
         insert into amor_etap                                                       -- insert di amor etap
               (id_ae,id_je,id_krd,nilai_ae,reset) values
               (idae,'A',new.id_krd,kr.by_adm,false);
             if substr(kr.akta_krd,7,1) = '1' then
               sadm := '13011';
         nocoa := j.d1_je;
             elseif substr(kr.akta_krd,7,1) = '2' then
               sadm := '13021';
         nocoa := j.d2_je;
             else 
               sadm := '13031';
         nocoa := j.d3_je;
             end if;
       --select into nocoa id_coa from coa where no_coa = sadm;
       idkredit := nextval('jurnal_detil_id_djr_seq');
             insert into jurnal_detil                                                 -- insert di jurnal detil kredit untuk amor
               (id_jr,id_djr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr)
               values
               (xjr,idkredit,sekarang(),nocoa,0,kr.by_adm,'Adm Kredit'||kt,true);
       insert into trans_amor (id_ae,id_djr,kredit_xa) values (idae,idkredit,kr.by_adm);            -- insert di trans_amor
           else
       sadm := '36000';                                                         -- langsung penerimaan, tidak perlu di amor
       nocoa := j.k_je;
       --select into nocoa id_coa from coa where no_coa = sadm;
             insert into jurnal_detil                                                 -- insert di jurnal_detil biaya
               (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr)
               values
               (xjr,sekarang(),nocoa,0,kr.by_adm,'Adm Kredit'||kt,true);
           end if;
   end if;    -- kr.by_adm

         if kr.by_asuransi > 0 then                     -- penanganan biaya asuransi
           if kr.pinjaman_krd > 5000000 then
             sprov := '25001';
           else
             sprov := '25001';
           end if; 
           select into nocoa id_coa from coa where no_coa = sprov;                 
           insert into jurnal_detil                                          -- insert biaya asuransi di jurnal_detil
             (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr
             )
             values
             (xjr,sekarang(),nocoa,0,kr.by_asuransi,'Asuransi'||kt,true
             );
         end if;
     
         if kr.by_provisi > 0 then                                                        -- penanganan provisi -- koreksi_amor1 200519
     select into j * from jenis_etap where id_je = 'P';
           if kr.pinjaman_krd > j.batas_je then
       idae := nextval('amor_etap_id_ae_seq');
       insert into amor_etap                                                        -- insert provisi di amor_etap
               (id_ae,id_je,id_krd,nilai_ae,reset) values
               (idae,'P',new.id_krd,kr.by_provisi,false);
             if substr(kr.akta_krd,7,1) = '1' then
               sprov := '13011';
         nocoa := j.d1_je;
             elseif substr(kr.akta_krd,7,1) = '2' then
               sprov := '13021';
         nocoa := j.d2_je;
             else 
               sprov := '13031';
         nocoa := j.d3_je;
             end if;
             --select into nocoa id_coa from coa where no_coa = sprov;
       idkredit := nextval('jurnal_detil_id_djr_seq');
             insert into jurnal_detil                                                      -- insert di jurnal_detl
               (id_jr,id_djr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr)
               values
               (xjr,idkredit,sekarang(),nocoa,0,kr.by_provisi,'Provisi'||kt,true);
             insert into trans_amor (id_ae,id_djr,kredit_xa) values (idae,idkredit,kr.by_provisi);                 -- insert di trans_amor
           else
             sprov := '35001';
       nocoa := j.k_je;
       --select into nocoa id_coa from coa where no_coa = sprov;
             insert into jurnal_detil
               (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr)
               values
               (xjr,sekarang(),nocoa,0,kr.by_provisi,'Provisi'||kt,true);
           end if; -- kr.pinjaman_krd     
         end if; -- kr.by_provisi

         if kr.fidusia_krd > 0 then                                                        -- biaya fidusia 3 mar 17
           select into nocoa id_coa from coa where no_coa = '25002';
           insert into jurnal_detil
             (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr
             )
             values
             (xjr,sekarang(),nocoa,0,kr.fidusia_krd,'Fidusia'||kt,true
             );
         end if; 
                                                                                  -- koreksi_amor1 200519
     if kr.komisi_krd > 0 then                                                    -- biasanya komisi_krd belum dimasukan, tetapi tetap ditangani
       select into j * from jenis_etap where id_je = 'K';
           if kr.pinjaman_krd > j.batas_je then                                       -- cek apakah diatas batas yang perlu di amor
         idae := nextval('amor_etap_id_ae_seq');
         insert into amor_etap                                                    -- insert di amor etap
               (id_ae,id_je,id_krd,nilai_ae,reset) values
               (idae,'K',new.id_krd,kr.komisi_krd,false);
             if substr(kr.akta_krd,7,1) = '1' then
               sadm := '13012';
         nocoa2 := j.k_je;                                                      -- coa beban ditangguhkan untuk kredit
         nocoa := j.k1_je;                                                      -- coa untuk debet (k1 = kredit untuk amor)
             elseif substr(kr.akta_krd,7,1) = '2' then
               sadm := '13022';
         nocoa2 := j.k_je;
         nocoa := j.k2_je;
             else 
               sadm := '13032';
         nocoa2 := j.k_je;
         nocoa := j.k3_je;
             end if;
       --select into nocoa id_coa from coa where no_coa = sadm;
         iddebet := nextval('jurnal_detil_id_djr_seq');
             insert into jurnal_detil                                                 -- insert di jurnal detil debet untuk komisi
               (id_jr,id_djr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr)
               values
               (xjr,iddebet,sekarang(),nocoa,kr.komisi_krd,0,'Komisi Kredit'||kt,true);
       insert into trans_amor (id_ae,id_djr) values (idae,iddebet);             -- insert di trans_amor
       insert into jurnal_detil                                                 -- insert di jurnal detil kredit untuk komisi
               (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr)
               values
               (xjr,sekarang(),nocoa2,0,kr.komisi_krd,'Komisi Kredit'||kt,true);
           else
             sadm := '45002';                                                         -- langsung di biayakan, tidak perlu di amor
       nocoa2 := j.d_je;                                                        -- debet
       nocoa := j.k_je;                                                         -- kredit
       --select into nocoa id_coa from coa where no_coa = sadm;
       insert into jurnal_detil                                                 -- insert di jurnal_detil biaya
               (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr)
               values
               (xjr,sekarang(),nocoa2,kr.komisi_krd,0,'Komisi Kredit'||kt,true);
             insert into jurnal_detil                                                 -- insert di jurnal_detil biaya
               (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr)
               values
               (xjr,sekarang(),nocoa,0,kr.komisi_krd,'Komisi Kredit'||kt,true);
           end if;
     end if;    -- kr.komisi_krd 
                                                                                      -- koreksi_amor1 200519
     if kr.mediator_krd > 0 then                                                  -- biasanya mediator_krd belum dimasukan, tetapi tetap ditangani
       select into j * from jenis_etap where id_je = 'M';
           if kr.pinjaman_krd > j.batas_je then                                       -- cek apakah diatas batas yang perlu di amor
         idae := nextval('amor_etap_id_ae_seq');
         insert into amor_etap                                                    -- insert di amor etap
               (id_ae,id_je,id_krd,nilai_ae,reset) values
               (idae,'M',new.id_krd,kr.komisi_krd,false);
             if substr(kr.akta_krd,7,1) = '1' then
               sadm := '13012';        
         nocoa2 := j.k_je;                                                      -- coa beban ditangguhkan untuk kredit
         nocoa := j.k1_je;                                                      -- coa untuk debet (k1 = kredit untuk amor)
             elseif substr(kr.akta_krd,7,1) = '2' then
               sadm := '13022';
         nocoa2 := j.k_je;                                                      -- coa beban ditangguhkan untuk kredit
         nocoa := j.k2_je;                                                      -- coa untuk debet (k1 = kredit untuk amor)
             else 
               sadm := '13032';
         nocoa2 := j.k_je;                                                      -- coa beban ditangguhkan untuk kredit
         nocoa := j.k3_je;                                                      -- coa untuk debet (k1 = kredit untuk amor)
             end if;
       --select into nocoa id_coa from coa where no_coa = sadm;
         iddebet := nextval('jurnal_detil_id_djr_seq');
             insert into jurnal_detil                                                 -- insert di jurnal detil debit untuk mediator
               (id_jr,id_djr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr)
               values
               (xjr,iddebet,sekarang(),nocoa,kr.mediator_krd,0,'Mediator Kredit'||kt,true);
       insert into trans_amor (id_ae,id_djr) values (idae,iddebet);             -- insert di trans_amor
       insert into jurnal_detil                                                 -- insert di jurnal detil kredit untuk mediator
               (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr)
               values
               (xjr,sekarang(),nocoa2,0,kr.mediator_krd,'Mediator Kredit'||kt,true);
           else
             sadm := '44018';                                                         -- langsung di biayakan, tidak perlu di amor
       nocoa2 := j.d_je;                                                        -- debet
       nocoa := j.k_je;                                                         -- kredit
       --select into nocoa id_coa from coa where no_coa = sadm;
       insert into jurnal_detil                                                 -- insert di jurnal_detil biaya
               (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr)
               values
               (xjr,sekarang(),nocoa2,kr.mediator_krd,0,'Mediator Kredit'||kt,true);
             insert into jurnal_detil                                                 -- insert di jurnal_detil biaya
               (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr)
               values
               (xjr,sekarang(),nocoa,0,kr.mediator_krd,'Mediator Kredit'||kt,true);
           end if;
     end if;    -- kr.mediator_krd 
     
         select into nocoa id_coa from coa where no_coa = '20001';  -- transaksi pencairan ke tabungan
 --        select into norektab no_rek from reknas where id_rek = kr.ambildari_krd;
         if kr.typebunga_krd = 'A' then
           insert into jurnal_detil
             (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr
             )
             values
             (xjr,sekarang(),nocoa,0,nonul(new.pokokt_xkrd)-nonul(kr.by_adm)-nonul(kr.by_asuransi)-nonul(kr.by_provisi)-nonul(kr.fidusia_krd)-nonul(kr.angsur_krd),rk.akta_krd||'/'||rk.nama_nas,true
             );
         else
           insert into jurnal_detil
             (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr
             )
             values
             (xjr,sekarang(),nocoa,0,nonul(new.pokokt_xkrd)-nonul(kr.by_adm)-nonul(kr.by_asuransi)-nonul(kr.by_provisi)-nonul(kr.fidusia_krd),rk.akta_krd||'/'||rk.nama_nas,true
             );
         end if;
         if kr.typebunga_krd = 'A' then  -- insert di jurnal_detil untuk cicilan pertama in Advance
--di kredit modal kerja dll
           if kr.biguna_krd ='10' then
             select into nocoa id_coa from coa where no_coa = '13010';
           elsif kr.biguna_krd = '20' then
             select into nocoa id_coa from coa where no_coa = '13020';
           else
             select into nocoa id_coa from coa where no_coa = '13030';
           end if;
           insert into jurnal_detil
             (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr
             )
             values
             (xjr,sekarang(),nocoa,0,kr.angsur_krd,'POKOK'||kt,true
             );
         end if;
--  Dari OB-sheet.sql untuk hapus buku (dihapus --* tgl 4 sept 2015, karena direksi memutuskan untuk jurnal manual pada saat hapus buku)
       elsif new.id_sandi = '38' or new.id_sandi = '39' then /* hapus buku & hapus tagih tidak perlu generate jurnal keu */

       else
         FOR p IN select id_coa,tab_prs,dk_prs,field_prs from proses where id_sandi = kode order by dk_prs LOOP
            k :=0;
            d :=0;
            if p.dk_prs = 'K' then
              k:= hitisi('K'::text,new.id_xkrd::int4,p.field_prs::int2);
            else
              d:= hitisi('K'::text,new.id_xkrd::int4,p.field_prs::int2);
            end if;
            insert into jurnal_detil
             (id_jr,tgl_djr,id_coa,debet_djr,kredit_djr,ket_djr,posted_djr
             )
             values
             (xjr,sekarang(),p.id_coa,d,k,kt,true
             );
         END LOOP;
       end if;
     end if;

     if new.id_sandi = '30' then
     end if;
  end if;
  return new;
end;

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION public.tambah_xkrd()
  OWNER TO bprdba;
