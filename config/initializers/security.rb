# Workaround for CVE-2013-0156.
ActionDispatch::ParamsParser::DEFAULT_PARSERS.delete(Mime::XML) 