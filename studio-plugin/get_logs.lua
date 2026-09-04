return function(targetInstance, data, ctx, targetPath)
    if #ctx.recentLogs == 0 then
        return { status = "success", result = {"Console kosong. Tidak ada error atau log terbaru."} }
    else
        return { status = "success", result = ctx.recentLogs }
    end
end
