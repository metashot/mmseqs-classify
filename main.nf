#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include { mmseqs_db_download; mmseqs_easy_taxonomy } from './modules/mmseqs'
include { metaeuk_easy_predict } from './modules/metaeuk'
include { eggnog_db_download; eggnog_mapper } from './modules/eggnog_mapper'
include { kofamscan } from './modules/kofamscan'
include { pseudochr; kofamscan_db_download; merge_eggnog_mapper; merge_kofamscan } from './modules/utils'

workflow {
    
    Channel
        .fromPath( params.genomes )
        .map { file -> tuple(file.baseName, file) }
        .set { genomes_ch }


    // MMseqs2 database
    if (!(params.skip_taxonomy && params.skip_genepred)) {
        if (params.mmseq_db == 'none') {
            mmseqs_db_download()
            mmseq_db_dir = mmseqs_db_download.out.mmseqs_db
            mmseq_db_name = "db"
        }
        else {
            mmseqs_db = file(params.mmseqs_db, checkIfExists: true)
            mmseq_db_dir = mmseqs_db.parent
            mmseq_db_name = mmseqs_db.name
        }
    }

    // MMseq2 taxonomy
    if ( !params.skip_taxonomy ) {
        if (!params.contigs) {
            pseudochr(genomes_ch)
            pseudochr_ch = pseudochr.out.pseudochr
        } else {
            pseudochr_ch = genomes_ch
        }

        mmseqs_easy_taxonomy(pseudochr_ch, mmseq_db_dir, mmseq_db_name)
        mmseqs_lca_ch = mmseqs_easy_taxonomy.out.lca
            .collectFile(
                name:'mmseqs_lca.txt', 
                storeDir: "${params.outdir}/mmseqs",
                newLine: false)
    }

    // MetaEuk
    if ( (!params.skip_genepred) || (!params.skip_eggnog) || params.run_kofamscan) {
        metaeuk_easy_predict(genomes_ch, mmseq_db_dir, mmseq_db_name)
        prot_ch = metaeuk_easy_predict.out.prot
    }

    // eggNOG
    if ( params.run_eggnog ) {
        if (params.eggnog_db == 'none') {
            eggnog_db_download()
            eggnog_db = eggnog_db_download.out.eggnog_db
        }
        else {
            eggnog_db = file(params.eggnog_db, type: 'dir', 
                checkIfExists: true)
        }

        eggnog_mapper(prot_ch, eggnog_db)
        merge_eggnog_mapper(eggnog_mapper.out.annotations.collect())
    }
    
    // KofamScan 
    if ( params.run_kofamscan ) {
        if (params.kofamscan_db == 'none') {
            kofamscan_db_download()
            kofamscan_db = kofamscan_db_download.out.kofamscan_db
        }
        else {
            kofamscan_db = file(params.kofamscan_db, type: 'dir', 
                checkIfExists: true)
        }

        kofamscan(prot_ch, kofamscan_db)
        merge_kofamscan(kofamscan.out.hits.collect())
    }
}
